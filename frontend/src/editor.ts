import * as monaco from 'monaco-editor';

const editorContainer = document.getElementById('app');
if (!editorContainer) {
  throw new Error('App container not found');
}

const editor = monaco.editor.create(editorContainer, {
  value: '// Welcome to Codnia IDE\n// Start coding here...\n\nfn main() {\n    println!("Hello, world!");\n}',
  language: 'rust',
  theme: 'vs-dark',
  fontSize: 13,
  fontFamily: 'SF Mono, Fira Code, Consolas, monospace',
  minimap: { enabled: true },
  automaticLayout: true,
  scrollBeyondLastLine: false,
  lineNumbers: 'on',
  renderWhitespace: 'selection',
  tabSize: 4,
  insertSpaces: true,
});

window.addEventListener('resize', () => {
  editor.layout();
});

console.log('Codnia Monaco Editor initialized');