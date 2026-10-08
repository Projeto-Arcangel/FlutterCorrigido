// Extração de texto de PDF no navegador, usada em "Questões com IA > Dos meus
// materiais". O arquivo nunca sai do computador do professor: só o texto vai
// para o servidor.
//
// pdf.js (Mozilla, Apache-2.0) fica em vendor/pdfjs/ — versão fixa, conferida
// com o pacote pdfjs-dist do npm. É carregado só na primeira leitura de PDF, e
// o trabalho pesado roda no worker dele (outra thread): a tela não trava.
(function () {
  let pdfjsPromise = null;

  function loadPdfjs() {
    if (!pdfjsPromise) {
      const base = new URL('vendor/pdfjs/', document.baseURI);
      pdfjsPromise = import(new URL('pdf.min.mjs', base).href).then((pdfjs) => {
        pdfjs.GlobalWorkerOptions.workerSrc =
          new URL('pdf.worker.min.mjs', base).href;
        return pdfjs;
      });
      // Se o carregamento falhar (rede), permite tentar de novo depois.
      pdfjsPromise.catch(() => { pdfjsPromise = null; });
    }
    return pdfjsPromise;
  }

  // Junta os trechos de texto de uma página respeitando as quebras de linha.
  function pageText(content) {
    let text = '';
    for (const item of content.items) {
      if (typeof item.str !== 'string') continue;
      text += item.str;
      if (item.hasEOL) text += '\n';
      else if (item.str && !item.str.endsWith(' ')) text += ' ';
    }
    return text.replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
  }

  /**
   * @param {Uint8Array} bytes conteúdo do PDF
   * @param {(done: number, total: number) => void} onProgress
   * @returns {Promise<string[]>} texto de cada página
   * Erros: rejeita com { code, message }, code em
   *   'password' | 'invalid' | 'load' | 'unknown'.
   */
  window.arcangelExtractPdfText = async function (bytes, onProgress) {
    let pdfjs;
    try {
      pdfjs = await loadPdfjs();
    } catch (e) {
      throw { code: 'load', message: String(e && e.message || e) };
    }

    // A "tarefa de carregamento" é quem libera o documento e o worker no fim
    // (no pdf.js 6 o documento em si não tem mais destroy()).
    let task;
    let doc;
    try {
      task = pdfjs.getDocument({
        data: bytes,
        // Endurecimento: sem eval de código vindo do PDF, sem fontes
        // embutidas (não renderizamos nada, só lemos o texto).
        isEvalSupported: false,
        disableFontFace: true,
        enableXfa: false,
      });
      doc = await task.promise;
    } catch (e) {
      if (task) task.destroy();
      const name = e && e.name;
      const code = name === 'PasswordException' ? 'password'
        : name === 'InvalidPDFException' ? 'invalid' : 'unknown';
      throw { code, message: String(e && e.message || e) };
    }

    const pages = [];
    try {
      for (let i = 1; i <= doc.numPages; i++) {
        const page = await doc.getPage(i);
        pages.push(pageText(await page.getTextContent()));
        page.cleanup();
        if (onProgress) onProgress(i, doc.numPages);
      }
    } finally {
      await task.destroy();
    }
    return pages;
  };
})();
