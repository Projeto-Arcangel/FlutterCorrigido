// Texto principal de uma página (artigo, notícia, verbete) para gerar
// questões. Usa o Readability — o mesmo algoritmo do "modo leitura" do
// Firefox — para separar o conteúdo de menus, anúncios e rodapés.

import { Readability } from "npm:@mozilla/readability@0.6.0";
import { parseHTML } from "npm:linkedom@0.18.13";

/** Elementos que começam uma nova linha no texto. */
const BLOCK = new Set([
  "ADDRESS", "ARTICLE", "ASIDE", "BLOCKQUOTE", "DD", "DIV", "DL", "DT",
  "FIGCAPTION", "FIGURE", "FOOTER", "H1", "H2", "H3", "H4", "H5", "H6",
  "HEADER", "HR", "LI", "MAIN", "OL", "P", "PRE", "SECTION", "TABLE", "TD",
  "TH", "TR", "UL",
]);
const SKIP = new Set([
  "SCRIPT", "STYLE", "NOSCRIPT", "TEMPLATE", "SVG", "CANVAS", "IFRAME",
  "BUTTON", "FORM", "INPUT", "SELECT", "TEXTAREA",
]);
/** Fora do artigo: só removidos quando o Readability não encontra o artigo. */
const CHROME = ["nav", "header", "footer", "aside", "menu", "[role=navigation]"];

export interface PageText {
  title: string;
  siteName: string | null;
  paragraphs: string[];
}

/** Decodifica os bytes da página pela codificação declarada (cabeçalho ou <meta>). */
export function decodeHtml(bytes: Uint8Array, contentType: string): string {
  let charset = contentType.match(/charset=["']?([\w-]+)/i)?.[1];
  if (!charset) {
    const head = new TextDecoder("latin1").decode(bytes.subarray(0, 4096));
    charset = head.match(/<meta[^>]+charset=["']?([\w-]+)/i)?.[1];
  }
  try {
    return new TextDecoder(charset ?? "utf-8").decode(bytes);
  } catch (_e) {
    return new TextDecoder("utf-8").decode(bytes);
  }
}

/**
 * Texto do nó em parágrafos: quebra de linha entre blocos (p, li, h2...) e em
 * <br>, espaços colapsados como o navegador faz. Cada trecho de texto entra
 * uma única vez.
 */
function toParagraphs(root: Node): string[] {
  const paragraphs: string[] = [];
  let line = "";

  const breakLine = () => {
    const text = line.replace(/\s+/g, " ").trim();
    if (text) paragraphs.push(text);
    line = "";
  };

  const walk = (node: Node) => {
    if (node.nodeType === 3) {
      line += node.textContent ?? "";
      return;
    }
    if (node.nodeType !== 1) return;
    const tag = (node as Element).tagName.toUpperCase();
    if (SKIP.has(tag)) return;
    if (tag === "BR") return breakLine();
    const block = BLOCK.has(tag);
    if (block) breakLine();
    for (const child of Array.from(node.childNodes)) walk(child);
    if (block) breakLine();
  };

  walk(root);
  breakLine();
  return paragraphs;
}

export function extractPageText(html: string, url: string): PageText {
  // Uma análise do HTML no caminho comum (CPU das Edge Functions é limitada);
  // o título é lido antes, porque o Readability altera o documento.
  const parsed = parseHTML(html).document;
  const pageTitle = parsed.querySelector("title")?.textContent?.trim() ?? "";
  // Limpeza ANTES do Readability, enquanto a estrutura original existe:
  // botões "[editar]" e marcas de citação fazem o Readability descartar os
  // títulos de seção (muitos links), e as seções de apoio só são
  // reconhecíveis pelos títulos.
  removeNoise(parsed.body);
  removeBackMatter(parsed.body);
  const article = new Readability(parsed as unknown as Document, {
    charThreshold: 300,
    // Devolve o artigo como nó, sem serializar para HTML e analisar de novo
    // (economiza CPU — o limite das Edge Functions é de 2 s por requisição).
    serializer: (node: Node) => node as unknown as string,
  }).parse();

  const content = article?.content as unknown as Node | undefined;
  if (content) {
    const paragraphs = cleanCitations(toParagraphs(content));
    // Readability às vezes pega só um trecho curto (ex.: legenda): sem texto
    // suficiente, cai para a página inteira.
    if (paragraphs.join(" ").length >= 300) {
      return {
        title: article?.title?.trim() || pageTitle || new URL(url).hostname,
        siteName: article?.siteName?.trim() || null,
        paragraphs,
      };
    }
  }

  // Sem artigo identificável: página inteira (nova análise, pois a anterior
  // foi alterada pelo Readability), sem menus/cabeçalhos/rodapés.
  const { document } = parseHTML(html);
  removeNoise(document.body);
  for (const selector of CHROME) {
    for (const el of Array.from(document.querySelectorAll(selector))) el.remove();
  }
  if (document.body) removeBackMatter(document.body);
  return {
    title: pageTitle || new URL(url).hostname,
    siteName: null,
    paragraphs: document.body ? cleanCitations(toParagraphs(document.body)) : [],
  };
}

/**
 * Seções de apoio que não são conteúdo para questões (Referências, Notas,
 * Bibliografia, Ligações externas, Ver também...): o título e tudo até o
 * próximo título do mesmo nível ou acima saem.
 */
const BACK_MATTER =
  /^(refer[eê]ncias?( bibliogr[aá]ficas)?|notas( e refer[eê]ncias)?|bibliografia|fontes|liga[cç][oõ]es externas|links externos|ver tamb[eé]m|leitura (adicional|complementar)|references|notes|bibliography|external links|see also|further reading)$/i;

/** Texto além do título que um invólucro de título pode ter ("[editar]"). */
const WRAPPER_SLACK = 60;

function textLength(el: Element): number {
  return (el.textContent ?? "").replace(/\s+/g, " ").trim().length;
}

function headingLevel(el: Element | null): number {
  if (!el) return 0;
  const m = el.tagName.match(/^H([1-6])$/i);
  if (m) return Number(m[1]);
  // Título embrulhado (ex.: <div class="mw-heading"><h2>…</h2> [editar]</div>):
  // o invólucro conta como título se quase todo o texto dele é o título.
  const inner = el.querySelector("h1,h2,h3,h4,h5,h6");
  if (inner && textLength(el) - textLength(inner) <= WRAPPER_SLACK) {
    return headingLevel(inner);
  }
  return 0;
}

function removeBackMatter(root: Element): void {
  for (const heading of Array.from(root.querySelectorAll("h1,h2,h3,h4,h5,h6"))) {
    if (!heading.isConnected) continue;
    const title = (heading.textContent ?? "")
      .replace(/\[\s*editar[^\]]*\]/gi, "")
      .replace(/\s+/g, " ")
      .trim();
    if (!BACK_MATTER.test(title)) continue;

    const level = headingLevel(heading);
    // Se o título está num invólucro (com no máximo o "[editar]"), a seção
    // são os irmãos do invólucro.
    let start: Element = heading;
    while (
      start.parentElement && start.parentElement !== root &&
      textLength(start.parentElement) - textLength(heading) <= WRAPPER_SLACK
    ) {
      start = start.parentElement;
    }
    let next = start.nextElementSibling;
    while (next) {
      const nextLevel = headingLevel(next);
      if (nextLevel > 0 && nextLevel <= level) break;
      const toRemove = next;
      next = next.nextElementSibling;
      toRemove.remove();
    }
    start.remove();
  }
}

/** Elementos que não são conteúdo: botões de edição e marcas de citação. */
const NOISE = [
  ".mw-editsection",
  "sup.reference",
  ".mw-cite-backlink",
  ".navbox",
  ".catlinks",
  ".printfooter",
];

function removeNoise(root: Element | null): void {
  if (!root) return;
  for (const el of Array.from(root.querySelectorAll(NOISE.join(",")))) {
    el.remove();
  }
}

/** Marcas de citação ("[12]", "[nota 3]") e "[editar]" não são conteúdo. */
function cleanCitations(paragraphs: string[]): string[] {
  return paragraphs
    .map((p) =>
      p.replace(/\[(?:\d{1,3}|nota \d{1,3}|[a-z])\]/gi, "")
        .replace(/\[\s*editar[^\]]*\]/gi, "")
        .replace(/\s{2,}/g, " ")
        .trim()
    )
    .filter(Boolean);
}
