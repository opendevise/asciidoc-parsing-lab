{{
const inlinePreprocessor = require('#inline-preprocessor')
}}
{
if (!input) return {}
const {
  attributes: documentAttributes = {},
  contentAttributeNames = ['title', 'reftext', 'caption', 'citetitle', 'attribution'],
  locations = { 1: { line: 1, col: 1 } },
  initial = {},
} = options
const { input: preprocessedInput, sourceMapping } = inlinePreprocessor(input, { attributes: documentAttributes, mode: 'attributes' })
if (!preprocessedInput) return {}
if (sourceMapping) input = preprocessedInput
const parseInline = (options.inlineParser ?? require('#block-default-inline-parser')).parse

function valueToInlines (value, valueOffset, parse, escapedChar, startLocation) {
  let inlines = []
  if (!value) return { value, inlines }
  if (parse) {
    let sourceMapping_ = sourceMapping && sourceMapping.slice(valueOffset, valueOffset + value.length)
    if (escapedChar && ~value.indexOf('\\')) {
      sourceMapping_ ??= [...Array(value.length)].map((_, offset) => ({ offset: offset + valueOffset }))
      const escapes = {}
      value = value.replace(new RegExp(`\\\\+(?=${escapedChar}|$)`, 'g'), (match, idx) => {
        let numBackslashes = match.length
        if (numBackslashes % 2) escapes[idx - 1 + numBackslashes--] = true
        if (!numBackslashes) return ''
        for (let i = 0; i < numBackslashes; i += 2) escapes[i + idx + 1] = true
        return match.slice(0, numBackslashes / 2)
      })
      if (Object.keys(escapes).length) sourceMapping_ = sourceMapping_.filter((it, idx) => !escapes[idx])
    }
    const locationsForInlines = {
      1: Object.assign({}, startLocation, { col: startLocation.col + (sourceMapping_ ? 0 : valueOffset) }),
    }
    inlines = parseInline(value, { locations: locationsForInlines, preprocessorMode: 'passthroughs', sourceMapping: sourceMapping_ })
  } else {
    let valueStartOffset, valueEndOffset
    if (sourceMapping) {
      if (Array.isArray((valueStartOffset = sourceMapping[valueOffset].offset))) valueStartOffset = valueStartOffset[0]
      if (Array.isArray((valueEndOffset = sourceMapping[valueOffset + value.length - 1].offset))) valueEndOffset = valueEndOffset[1]
    } else {
      valueEndOffset = (valueStartOffset = valueOffset) + value.length - 1
    }
    if (escapedChar && ~value.indexOf('\\')) {
      value = value.replace(new RegExp(`\\\\+(?=${escapedChar}|$)`, 'g'), (match) => '\\'.repeat(Math.floor(match.length / 2)))
    }
    const inlinesSourceLocation = [
      Object.assign({}, startLocation, { col: startLocation.col + valueStartOffset }),
      Object.assign({}, startLocation, { col: startLocation.col + valueEndOffset }),
    ]
    inlines = [{ type: 'string', name: 'text', value: value, location: inlinesSourceLocation }]
  }
  return { value, inlines }
}
}
// Q: is there a simpler way to handle attrsOffset here?
block_attrlist = anchor:block_anchor? attrsOffset:offset attrs:(!. / block_attr|.., ',' ' '* / ' '+ (',' ' '*)?|)
  {
    if (anchor) {
      initial['$1'] = input.slice(offset(), attrsOffset)
      initial.id = anchor[0]
      if (anchor[1]) initial.reftext = anchor[1]
    }
    if (!attrs) return initial
    let posIdx = 0
    return attrs.reduce((accum, [name, value], idx) => {
      if (name == null) {
        const posKey = `$${++posIdx}`
        if (!value || ((idx || ~value.indexOf(' ')) && (accum[posKey] = value))) return accum
        // NOTE shorthands only parsed if first positional attribute is in first position in attrlist and value has no spaces
        accum[posKey] = anchor ? accum[posKey] + value : value
        const m = value.split(/([.#%])/)
        if (m.length > 1) {
          let style
          for (let i = 0, len = m.length, val, chr0; i < len; i += 2) {
            if ((val = m[i]) && ((chr0 = m[i - 1]) || !(style = val))) {
              if (chr0 === '#') {
                accum.id = val
              } else if (chr0 === '.') {
                ;(accum.role ??= new Set()).add(val)
              } else {
                ;(accum.opts ??= new Set()).add(val)
              }
            }
          }
          if (style) accum.style = style
        } else {
          accum.style = value
        }
      } else if (name === 'role' || name === 'roles') {
        value && (value = value.split(' ').filter((it) => it !== '')).length &&
          value.reduce((names, name) => names.add(name), (accum.role ??= new Set()))
      } else if (name === 'opts' || name === 'options') {
        value && (value = value.split(/,| /).filter((it) => it !== '')).length &&
          value.reduce((names, name) => names.add(name), (accum.opts ??= new Set()))
      } else {
        accum[name] = value
      }
      return accum
    }, initial)
  }

block_anchor = '[' @idname @(',' ' '* @(valueOffset:offset value:$('\\' ('\\' / ']') / (!']' .))* { return valueToInlines(value, valueOffset, true, ']', locations['1']) }))? ']'

block_attr = @name:(@block_attr_name ('=' !' ' / ' '* '=' ' '*))? @(&{ return name && ~contentAttributeNames.indexOf(name) } @block_content_attr_val / block_attr_val)

// TODO support unicode alpha
block_attr_name = $([a-zA-Z_] [a-zA-Z0-9_-]*)

// TODO support unicode alpha
idname = $([a-zA-Z_:] [a-zA-Z0-9_\-:.]*)

block_content_attr_val = valueRecord:(double_quoted_attr_val / single_quoted_attr_val / unquoted_attr_val)
  {
    const [quote, valueOffset, value] = valueRecord
    return valueToInlines(value, valueOffset, quote === '\'', quote, locations['1'])
  }

block_attr_val = valueRecord:(double_quoted_attr_val / single_quoted_attr_val / unquoted_attr_val)
  {
    const [quote, _, value] = valueRecord
    return quote && ~value.indexOf('\\')
      ? value.replace(new RegExp(`\\\\+(?=${quote}|$)`, 'g'), (match) => match.slice(0, Math.floor(match.length / 2)))
      : value
  }

double_quoted_attr_val = @'"' @offset @$('\\' ('\\' / '"') / (!'"' .))* '"' &(!. / ',' / ' ')

single_quoted_attr_val = @'\'' @offset @$('\\' ('\\' / '\'') / (!'\'' .))* '\'' &(!. / ',' / ' ')

unquoted_attr_val = '' offset $(!(',' / ' ') . / ' '+ !',' &.)*

offset = ''
  {
    return peg$currPos
  }
