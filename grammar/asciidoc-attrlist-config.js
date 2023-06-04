'use strict'

module.exports = {
  allowedStartRules: ['block_attrlist'],
  cache: false,
  format: 'commonjs',
  input: 'grammar/asciidoc-attrlist.pegjs',
  output: './lib/asciidoc-attrlist-parser.js',
}
