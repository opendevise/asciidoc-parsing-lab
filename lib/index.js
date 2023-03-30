'use strict'

const blockParser = require('./asciidoc-block-parser')
const inlineParser = require('./asciidoc-inline-parser')

function parse (input, { attributes, parseInlines } = {}) {
  return blockParser.parse(input, parseInlines ? { inlineParser } : {})
}

module.exports = parse
