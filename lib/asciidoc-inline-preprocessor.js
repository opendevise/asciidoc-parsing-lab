'use strict'

const Rules = {
  attributeReference: '\\{([\\p{Ll}0-9_][\\p{Ll}0-9_-]*)\\}',
  escapeAny: '(\\\\)[\\\\{+p]',
  escapePassthrough: '(\\\\)[+p]',
  constrainedPass: '(?<![\\p{Alpha}0-9])\\+([^\\s\\\\]|\\S.*?[^\\s\\\\])\\+(?![\\p{Alpha}0-9])',
  passMacro: 'pass:\\[(.*?[^\\\\])\\]',
  unconstrainedPass: '\\+\\+(.*?[^+\\\\])\\+\\+',
}

const GrammarRx = new RegExp([
  Rules.escapeAny,
  Rules.attributeReference,
  Rules.unconstrainedPass,
  Rules.constrainedPass,
  Rules.passMacro,
].join('|'), 'gu')

const AttributeReferencesOnlyGrammarRx = new RegExp('(\\\\+)?' + Rules.attributeReference, 'gu')

const PassthroughsOnlyGrammarRx = new RegExp([
  Rules.escapePassthrough,
  Rules.unconstrainedPass,
  Rules.constrainedPass,
  Rules.passMacro,
].join('|'), 'gu')

module.exports = (input, { attributes, mode, sourceMapping } = {}) => {
  let modified, replaceArgs
  if (!mode) {
    if (~input.indexOf('{') || ~input.indexOf('+') || ~input.indexOf('pass:')) {
      attributes ??= {}
      replaceArgs = [
        GrammarRx,
        (match, esc, attr, unconstrainedContents, constrainedContents, macroContents, offset) => {
          if (esc) return match
          if (attr) {
            const replacement = replaceAttributeReference(match, undefined, attr, attributes, sourceMapping, offset)
            return replacement == null ? match : (modified = true) && replacement
          }
          modified = true
          return replacePassthrough(unconstrainedContents, constrainedContents, macroContents, sourceMapping, offset)
        },
      ]
    }
  } else if (mode === 'attributes') {
    if (~input.indexOf('{')) {
      attributes ??= {}
      replaceArgs = [
        AttributeReferencesOnlyGrammarRx,
        (match, backslashes, attr, offset) => {
          const replacement = replaceAttributeReference(match, backslashes, attr, attributes, sourceMapping, offset)
          return replacement == null ? match : (modified = true) && replacement
        },
      ]
    }
  } else if (mode === 'passthroughs') {
    if (~input.indexOf('+') || ~input.indexOf('pass:')) {
      replaceArgs = [
        PassthroughsOnlyGrammarRx,
        (match, esc, unconstrainedContents, constrainedContents, macroContents, offset) => {
          if (esc) return match
          modified = true
          return replacePassthrough(unconstrainedContents, constrainedContents, macroContents, sourceMapping, offset)
        },
      ]
    }
  }
  if (replaceArgs) {
    const providedSourceMapping = sourceMapping
    ;(sourceMapping ??= [...Array(input.length)].map((_, offset) => ({ offset }))) && (sourceMapping.offset = 0)
    const preprocessedInput = input.replace.apply(input, replaceArgs)
    delete sourceMapping.offset
    modified ? (input = preprocessedInput) : (sourceMapping = providedSourceMapping)
  }
  return sourceMapping ? { input, sourceMapping } : { input }
}

function replaceAttributeReference (match, backslashes, attr, attributes, sourceMapping, from) {
  let esc, nextSourceOffset, newSize, sourceOffsetRange, value
  if (backslashes) {
    const numBackslashes = backslashes.length
    esc = numBackslashes % 2 > 0
    const numResolvedBackslashes = Math.floor(numBackslashes / 2)
    newSize = (value = match = match.slice(numBackslashes)).length
    if (esc) {
      match = '\\' + value
    } else if (attr in attributes) {
      newSize = (value = attributes[attr]).length
    } else {
      esc = true
    }
    if (!sourceMapping) return numResolvedBackslashes ? backslashes.slice(0, numResolvedBackslashes) + value : value
    if (numResolvedBackslashes) {
      value = backslashes.slice(0, numResolvedBackslashes) + value
      const fromBackslashesAdjusted = from - sourceMapping.offset
      nextSourceOffset = sourceMapping[fromBackslashesAdjusted].offset
      for (let i = fromBackslashesAdjusted, len = fromBackslashesAdjusted + numResolvedBackslashes; i < len; i++) {
        sourceMapping.splice(i, 2, { offset: nextSourceOffset })
        nextSourceOffset += 2
      }
      from += numResolvedBackslashes
    }
  } else if (attr in attributes) {
    newSize = (value = attributes[attr]).length
    if (!sourceMapping) return value
  } else {
    return
  }
  const oldSize = match.length
  const delta = newSize - oldSize
  const fromAdjusted = from - sourceMapping.offset
  const toAdjusted = fromAdjusted + oldSize
  const sourceOffset = sourceMapping[fromAdjusted].offset
  if (esc) {
    nextSourceOffset = sourceOffset
    for (let i = fromAdjusted, len = toAdjusted; i < len; i++) sourceMapping[i] = { offset: ++nextSourceOffset }
    if (match !== value) sourceMapping[fromAdjusted].offset-- // attribute { to location of backslash
  } else {
    sourceOffsetRange = [sourceOffset, sourceOffset + oldSize - 1]
    for (let i = fromAdjusted, len = toAdjusted; i < len; i++) sourceMapping[i] = { offset: sourceOffsetRange, attr }
    if (!delta) return value
  }
  if (delta > 0) {
    const insert = []
    for (let i = toAdjusted, len = toAdjusted + delta; i < len; i++) insert.push({ offset: sourceOffsetRange, attr })
    sourceMapping.splice(fromAdjusted + 1, 0, ...insert)
    nextSourceOffset = sourceOffsetRange[1]
    for (let i = toAdjusted + delta, len = sourceMapping.length; i < len; i++) {
      sourceMapping[i] = { offset: ++nextSourceOffset }
    }
  } else if (delta < 0) {
    sourceMapping.splice(fromAdjusted + newSize, -delta)
  }
  sourceMapping.offset -= delta // Q: does this need to go just after sourceOffset is set?
  return value
}

function replacePassthrough (unconstrainedContents, constrainedContents, macroContents, sourceMapping, from) {
  let contents, form, to
  if ((contents = unconstrainedContents)) {
    form = 'unconstrained'
    to = from + contents.length + 4
  } else if ((contents = constrainedContents)) {
    form = 'constrained'
    to = from + contents.length + 2
  } else if ((contents = macroContents)) {
    form = 'macro'
    to = from + contents.length + 7
  }
  const fromAdjusted = from - sourceMapping.offset
  const toAdjusted = to - sourceMapping.offset
  Object.assign(sourceMapping[fromAdjusted], { contents, form })
  for (let i = fromAdjusted; i < toAdjusted; i++) sourceMapping[i].pass = true
  return '\u0010' + '\u0000'.repeat(to - from - 1)
}
