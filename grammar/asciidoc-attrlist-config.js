'use strict'

module.exports = {
  allowedStartRules: ['block_attrlist', 'block_attrlist_with_shorthands'],
  cache: false,
  format: 'commonjs',
  input: 'grammar/asciidoc-attrlist.pegjs',
  output: './lib/asciidoc-attrlist-parser.js',
}
