'use strict'

const SyntaxRx = new RegExp(
  '(\\\\)[\\\\{+p]|' +
  '\\{([\\p{Ll}0-9_][\\p{Ll}0-9_-]*)\\}|' +
  '\\+\\+(.*?[^+\\\\])\\+\\+|' +
  '(?<![\\p{Alpha}0-9])\\+([^\\s\\\\]|\\S.*?[^\\s\\\\])\\+(?![\\p{Alpha}0-9])|' +
  'pass:\\[(.*?[^\\\\])\\]',
  'gu'
)

module.exports = (input, { attributes = {}, sourceMapping } = {}) => {
  if (!~input.indexOf('{') && !~input.indexOf('+') && !~input.indexOf('pass:')) return { input }
  sourceMapping ??= [...Array(input.length)].map((_, offset) => ({ offset }))
  let currOffset = 0
  const preprocessedInput = input.replace(
    SyntaxRx,
    (match, esc, attr, unconstrainedContents, constrainedContents, macroContents, offset) => {
      if (esc) {
        return match
      } else if (attr) {
        if (attr in attributes) {
          const value = attributes[attr]
          const newSize = value.length
          const from = offset
          const to = from + attr.length + 1
          const fromAdjusted = from - currOffset
          const sourceOffset = sourceMapping[fromAdjusted].offset
          const toAdjusted = to - currOffset
          const oldSize = to - from + 1
          const sourceOffsetRange = [sourceOffset, sourceOffset + oldSize - 1]
          for (let i = fromAdjusted, len = toAdjusted + 1; i < len; i++) {
            sourceMapping[i] = { offset: sourceOffsetRange, attr }
          }
          const delta = newSize - oldSize
          if (delta) {
            if (delta > 0) {
              const insert = []
              for (let i = toAdjusted + 1, len = toAdjusted + 1 + delta; i < len; i++) {
                insert.push({ offset: sourceOffsetRange, attr })
              }
              sourceMapping.splice(fromAdjusted + 1, 0, ...insert)
              let nextSourceOffset = sourceOffsetRange[1]
              for (let i = toAdjusted + 1 + delta, len = sourceMapping.length; i < len; i++) {
                sourceMapping[i] = { offset: ++nextSourceOffset }
              }
            } else if (delta < 0) {
              sourceMapping.splice(fromAdjusted + newSize, -delta)
            }
            currOffset -= delta
          }
          return value
        } else {
          return match
        }
      } else {
        const from = offset
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
        return '\u0010' + '\u0000'.repeat(to - from - 1)
      }
    }
  )
  return { input: preprocessedInput, sourceMapping }
}
