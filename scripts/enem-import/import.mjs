// Importa o dataset enem.dev (2009–2023) para o Supabase:
//   1. Sobe as imagens de cada questão para o bucket `enem-questions`
//      (mesmo caminho relativo do enem.dev: {ano}/questions/{n}/{arquivo}).
//   2. Reescreve as URLs https://enem.dev/... -> URL pública do Storage.
//   3. Faz upsert das questões na tabela `enem_questions`
//      (idempotente via unique(year, index, language)).
//
// Uso (defina as variáveis de ambiente):
//   SUPABASE_URL                 ex.: http://127.0.0.1:54321  ou https://<ref>.supabase.co
//   SUPABASE_SERVICE_ROLE_KEY    chave service_role (LOCAL: JWT demo / CLOUD: dashboard)
//   ENEM_DIR                     default: D:\DownloadsHD\questoes
//   ENEM_YEARS                   opcional, ex.: "2022,2023" (default: todos)
//   ENEM_SKIP_IMAGES=1           opcional: pula upload de imagens (só dados)
//   ENEM_DRY_RUN=1               opcional: não envia nada, só conta/parseia
//
//   node scripts/enem-import/import.mjs

import { createClient } from '@supabase/supabase-js';
import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, extname } from 'node:path';

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ENEM_DIR = process.env.ENEM_DIR ?? 'D:\\DownloadsHD\\questoes';
const BUCKET = process.env.ENEM_BUCKET ?? 'enem-questions';
const YEARS = process.env.ENEM_YEARS
  ? process.env.ENEM_YEARS.split(',').map((s) => s.trim())
  : null;
const SKIP_IMAGES = process.env.ENEM_SKIP_IMAGES === '1';
const DRY_RUN = process.env.ENEM_DRY_RUN === '1';

if (!SUPABASE_URL || !SERVICE_KEY) {
  console.error('ERRO: defina SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY.');
  process.exit(1);
}

const ENEM_BASE = 'https://enem.dev/';
const STORAGE_BASE = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/`;

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

const CONTENT_TYPES = {
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.bmp': 'image/bmp',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.latex': 'text/plain; charset=utf-8',
};

/** Troca o host do enem.dev pela URL pública do Storage (mesmo caminho relativo). */
function rewrite(text) {
  if (typeof text !== 'string') return text;
  return text.split(ENEM_BASE).join(STORAGE_BASE);
}

/** Pool de concorrência simples. */
async function pool(items, size, fn) {
  let i = 0;
  const worker = async () => {
    while (i < items.length) {
      const idx = i++;
      await fn(items[idx]);
    }
  };
  await Promise.all(Array.from({ length: Math.min(size, items.length) }, worker));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Executa `fn` (que retorna o `error` do supabase-js ou null) com retry e
 * backoff em erros transitórios (timeout, 5xx, fetch failed). Trata
 * "já existe" como sucesso — torna a importação idempotente e retomável.
 */
async function withRetry(label, fn, tries = 6) {
  for (let attempt = 1; ; attempt++) {
    let err;
    try {
      err = await fn();
    } catch (e) {
      err = e; // exceção de rede (ex.: fetch failed)
    }
    if (!err) return;
    const msg = (err.message || String(err)).toLowerCase();
    const code = `${err.statusCode ?? err.status ?? ''}`;
    if (code === '409' || msg.includes('already exists') || msg.includes('duplicate')) {
      return; // objeto já estava lá → ok
    }
    if (attempt >= tries) throw new Error(`${label}: ${err.message || err}`);
    await sleep(800 * attempt); // 0.8s, 1.6s, 2.4s, ...
  }
}

async function uploadImage({ local, storagePath }) {
  const body = readFileSync(local);
  const contentType =
    CONTENT_TYPES[extname(local).toLowerCase()] ?? 'application/octet-stream';
  // upsert:false → se já existe, withRetry trata como sucesso (re-run rápido).
  await withRetry(`upload ${storagePath}`, async () => {
    const { error } = await supabase.storage
      .from(BUCKET)
      .upload(storagePath, body, { contentType, upsert: false });
    return error;
  });
}

function listYears() {
  return readdirSync(ENEM_DIR)
    .filter(
      (n) => /^\d{4}$/.test(n) && statSync(join(ENEM_DIR, n)).isDirectory(),
    )
    .filter((n) => !YEARS || YEARS.includes(n))
    .sort();
}

async function main() {
  const years = listYears();
  console.log(`Dataset: ${ENEM_DIR}`);
  console.log(`Destino: ${SUPABASE_URL} (bucket ${BUCKET})`);
  console.log(`Anos: ${years.join(', ') || '(nenhum)'}${DRY_RUN ? ' [DRY-RUN]' : ''}`);

  let totalImg = 0;
  let totalQ = 0;

  for (const year of years) {
    const qDir = join(ENEM_DIR, year, 'questions');
    if (!existsSync(qDir)) continue;
    const indices = readdirSync(qDir).filter((n) =>
      statSync(join(qDir, n)).isDirectory(),
    );

    const uploads = [];
    const yearRows = [];
    for (const ind of indices) {
      const dir = join(qDir, ind);
      const detailsPath = join(dir, 'details.json');
      if (!existsSync(detailsPath)) continue;
      const j = JSON.parse(readFileSync(detailsPath, 'utf8'));

      if (!SKIP_IMAGES) {
        for (const f of readdirSync(dir)) {
          if (f === 'details.json') continue;
          uploads.push({
            local: join(dir, f),
            storagePath: `${year}/questions/${ind}/${f}`,
          });
        }
      }

      yearRows.push({
        year: j.year,
        index: j.index,
        discipline: j.discipline ?? '',
        language: j.language ?? '',
        context: rewrite(j.context ?? ''),
        context_images: (j.files ?? []).map(rewrite),
        alternatives_introduction: j.alternativesIntroduction ?? '',
        correct_alternative: j.correctAlternative ?? '',
        alternatives: (j.alternatives ?? []).map((a) => ({
          ...a,
          file: rewrite(a.file),
        })),
      });
    }

    // 1) Sobe as imagens do ano (idempotente: pula as que já existem, com retry).
    if (uploads.length && !DRY_RUN) {
      let done = 0;
      await pool(uploads, 10, async (u) => {
        await uploadImage(u);
        if (++done % 300 === 0) console.log(`  [${year}] imagens ${done}/${uploads.length}`);
      });
    }

    // 2) Upsert das questões do ano (com retry) — progresso salvo a cada ano.
    if (yearRows.length && !DRY_RUN) {
      await withRetry(`upsert ${year}`, async () => {
        const { error } = await supabase
          .from('enem_questions')
          .upsert(yearRows, { onConflict: 'year,index,language' });
        return error;
      });
    }

    totalImg += uploads.length;
    totalQ += yearRows.length;
    console.log(`Ano ${year}: ${yearRows.length} questões${DRY_RUN ? '' : ' (upsert ok)'} | ${uploads.length} imagens`);
  }

  console.log(
    `\nConcluído. Questões: ${totalQ}${DRY_RUN ? ' (dry-run)' : ''} | imagens: ${totalImg}.`,
  );
}

main().catch((e) => {
  console.error('\nFALHOU:', e.message);
  process.exit(1);
});
