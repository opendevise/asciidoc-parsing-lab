'use strict'

module.exports = {
  allowedStartRules: ['document'],
  cache: false,
  format: 'commonjs',
  input: 'grammar/asciidoc-preprocessor.pegjs',
  output: './lib/asciidoc-preprocessor-parser.js',
  //plugins: ['./grammar/peggy-compiler-patch.js'],
}
