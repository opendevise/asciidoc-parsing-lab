'use strict'

module.exports = {
  allowedStartRules: ['document'],
  cache: false,
  format: 'commonjs',
  input: 'grammar/asciidoc-block.pegjs',
  output: './lib/asciidoc-block-parser.js',
  //plugins: ['./grammar/peggy-compiler-patch.js'],
}
