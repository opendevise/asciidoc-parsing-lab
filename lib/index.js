'use strict'

const blockParser = require('./asciidoc-block-parser')
const inlineParser = require('./asciidoc-inline-parser')
const preprocessorParser = require('./asciidoc-preprocessor-parser.js')

function parse (input, { attributes, parseInlines, preprocessLines = true, showWarnings } = {}) {
  const options = { attributes: prepareDocumentAttributes(attributes) }
  if (preprocessLines) {
    const { input: preprocessedInput, locations } = preprocessorParser.parse(input, options)
    if (locations) {
      if (Object.keys(locations).length) {
        for (const l in locations) delete locations[l].lineOffset
        options.locations = locations
      }
      input = preprocessedInput
    }
  }
  if (parseInlines) options.inlineParser = inlineParser
  if (showWarnings) options.showWarnings = true
  return blockParser.parse(input, options)
}

function prepareDocumentAttributes (seed = {}) {
  const entries = Array.isArray(seed)
    ? seed.map((entry) => {
      const idx = (entry = String(entry)).indexOf('=')
      return ~idx ? [entry.slice(0, idx), entry.slice(idx + 1)] : [entry, '']
    })
    : Object.entries(seed)
  return entries.reduce((accum, [name, value, locked = true]) => {
    if (value?.constructor === String) {
      if (name[name.length - 1] === '@') {
        name = (locked = false) || name.slice(0, -1) // 'name@': 'value'
        if (name[0] === '!') {
          name = (value = null) || name.slice(1) // '!name@': ''
        } else if (name[name.length - 1] === '!') {
          name = (value = null) || name.slice(0, -1) // 'name!@': ''
        }
      } else if (value === '@' || (value && value[value.length - 1] === '@')) {
        if ((locked = false) || name[0] === '!') {
          name = (value = null) || name.slice(1) // '!name': '@'
        } else if (name[name.length - 1] === '!') {
          name = (value = null) || name.slice(0, -1) // 'name!': '@'
        } else {
          value = value.slice(0, -1) // 'name': '@', 'name': 'value@'
        }
      } else if (name[0] === '!') {
        name = (value = null) || name.slice(1) // '!name': ''
      } else if (name[name.length - 1] === '!') {
        name = (value = null) || name.slice(0, -1) // 'name!': ''
      }
    } else {
      value = value ? '' : value == null ? null : (locked = false) || null // 'name': true, 'name': false, 'name': null
    }
    const valueObject = { value, origin: 'external' }
    if (locked) valueObject.locked = true
    return Object.assign(accum, { [name]: valueObject })
  }, {})
}

module.exports = parse
