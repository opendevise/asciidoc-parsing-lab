'use strict'

module.exports = {
  allowedStartRules: ['root'],
  cache: false,
  format: 'commonjs',
  input: 'grammar/asciidoc-inline.pegjs',
  output: './lib/asciidoc-inline-parser.js',
  plugins: ['./grammar/peggy-compiler-patch.js'],
}
