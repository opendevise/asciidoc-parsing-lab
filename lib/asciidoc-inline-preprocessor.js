'use strict'

const Rules = {
  attributeReference: '\\{([\\p{Ll}0-9_][\\p{Ll}0-9_-]*)\\}',
  escapeAny: '(\\\\)[\\\\{+p]',
  escapePassthrough: '(\\\\)[+p]',
  constrainedPass: '(?<![\\p{Alpha}0-9])\\+([^\\s\\\\]|\\S.*?[^\\s\\\\])\\+(?![\\p{Alpha}0-9])',
  passMacro: 'pass:\\[(.*?[^\\\\])\\]',
  unconstrainedPass: '\\+\\+(.*?[^+\\\\])\\+\\+',
  voidCapture: '$(^)',
}

const GrammarRx = new RegExp([
  Rules.escapeAny,
  Rules.attributeReference,
  Rules.unconstrainedPass,
  Rules.constrainedPass,
  Rules.passMacro,
].join('|'), 'gu')

const PassthroughsOnlyGrammarRx = new RegExp([
  Rules.escapePassthrough,
  Rules.voidCapture,
  Rules.unconstrainedPass,
  Rules.constrainedPass,
  Rules.passMacro,
].join('|'), 'gu')

module.exports = (input, { attributes = {}, mode, sourceMapping } = {}) => {
  let expectAny = ['{', '+', 'pass:']
  let grammarRx = GrammarRx
  let skipPassthroughs = false
  if (mode === 'passthroughs') {
    expectAny = ['+', 'pass:']
    grammarRx = PassthroughsOnlyGrammarRx
  } else if ((skipPassthroughs = mode === 'attributes')) {
    expectAny = ['{']
    grammarRx = GrammarRx
  }
  if (!expectAny.some((str) => ~input.indexOf(str))) return sourceMapping ? { input, sourceMapping } : { input }
  sourceMapping ??= [...Array(input.length)].map((_, offset) => ({ offset }))
  let currOffset = 0
  let modified
  const preprocessedInput = input.replace(
    grammarRx,
    (match, esc, attr, unconstrainedContents, constrainedContents, macroContents, from) => {
      if (esc) return match
      if (attr) {
        if (!(attr in attributes)) return match
        const value = attributes[attr]
        const oldSize = match.length
        const newSize = value.length
        const delta = newSize - oldSize
        const fromAdjusted = from - currOffset
        const toAdjusted = fromAdjusted + oldSize
        const sourceOffset = sourceMapping[fromAdjusted].offset
        const sourceOffsetRange = [sourceOffset, sourceOffset + oldSize - 1]
        for (let i = fromAdjusted, len = toAdjusted; i < len; i++) {
          sourceMapping[i] = { offset: sourceOffsetRange, attr }
        }
        modified = true
        if (!delta) return value
        if (delta > 0) {
          const insert = []
          for (let i = toAdjusted, len = toAdjusted + delta; i < len; i++) {
            insert.push({ offset: sourceOffsetRange, attr })
          }
          sourceMapping.splice(fromAdjusted + 1, 0, ...insert)
          let nextSourceOffset = sourceOffsetRange[1]
          for (let i = toAdjusted + delta, len = sourceMapping.length; i < len; i++) {
            sourceMapping[i] = { offset: ++nextSourceOffset }
          }
        } else if (delta < 0) {
          sourceMapping.splice(fromAdjusted + newSize, -delta)
        }
        currOffset -= delta
        return value
      }
      if (skipPassthroughs) return match
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
      const fromAdjusted = from - currOffset
      const toAdjusted = to - currOffset
      Object.assign(sourceMapping[fromAdjusted], { contents, form })
      for (let i = fromAdjusted; i < toAdjusted; i++) sourceMapping[i].pass = true
      modified = true
      return '\u0010' + '\u0000'.repeat(to - from - 1)
    }
  )
  return modified ? { input: preprocessedInput, sourceMapping } : { input }
}
