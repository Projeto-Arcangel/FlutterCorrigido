// Divisão do texto lido no servidor (páginas, transcrições de vídeo) nos
// trechos que o app usa para recortar um material grande de forma espalhada.

/** Agrupa parágrafos em trechos de ~[blockChars] (unidade do recorte no app). */
export function toSegments(paragraphs: string[], blockChars = 2000): string[] {
  const segments: string[] = [];
  let current = "";
  for (const paragraph of paragraphs) {
    current = current ? `${current}\n${paragraph}` : paragraph;
    if (current.length >= blockChars) {
      segments.push(current);
      current = "";
    }
  }
  if (current) segments.push(current);
  return segments;
}
