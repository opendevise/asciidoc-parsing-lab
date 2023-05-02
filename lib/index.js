'use strict'

const blockParser = require('./asciidoc-block-parser')
const inlineParser = require('./asciidoc-inline-parser')
const preprocessorParser = require('./asciidoc-preprocessor-parser.js')

function parse (input, { attributes, parseInlines } = {}) {
  const { input: preprocessedInput, locations } = preprocessorParser.parse(input, { attributes })
  const options = { attributes }
  if (locations) {
    for (const l in locations) delete locations[l].lineOffset
    options.locations = locations
    input = preprocessedInput
  }
  if (parseInlines) options.inlineParser = inlineParser
  return blockParser.parse(input, options)
}

module.exports = parse
