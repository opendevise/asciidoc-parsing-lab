'use strict'

const blockParser = require('./asciidoc-block-parser')
const inlineParser = require('./asciidoc-inline-parser')
const preprocessorParser = require('./asciidoc-preprocessor-parser.js')

function parse (input, { attributes, parseInlines, showWarnings } = {}) {
  const { input: preprocessedInput, locations } = preprocessorParser.parse(input, { attributes })
  const options = { attributes }
  if (locations) {
    if (Object.keys(locations).length) {
      for (const l in locations) delete locations[l].lineOffset
      options.locations = locations
    }
    input = preprocessedInput
  }
  if (parseInlines) options.inlineParser = inlineParser
  if (showWarnings) options.showWarnings = true
  return blockParser.parse(input, options)
}

module.exports = parse
