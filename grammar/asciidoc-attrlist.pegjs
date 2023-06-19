{{
const inlinePreprocessor = require('#inline-preprocessor')
const { addAllToSet } = require('#util')
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
block_attrlist = shorthandAttrs:block_shorthand_attrs? attrs:(!. / block_attr|.., ',' ' '* / ' '+ (',' ' '*)?|)
  {
    let posIdx = 0
    if (shorthandAttrs) {
      if ('$1' in shorthandAttrs) {
        shorthandAttrs.role &&= addAllToSet((initial.role ??= new Set()), shorthandAttrs.role)
        shorthandAttrs.opts &&= addAllToSet((initial.opts ??= new Set()), shorthandAttrs.opts)
        Object.assign(initial, shorthandAttrs)
      }
      posIdx = 1
    }
    if (!attrs) return initial
    return attrs.reduce((accum, [name, value]) => {
      if (name == null) {
        const posKey = `$${++posIdx}`
        if (value) accum[posKey] = value
        return accum
      } else if (name === 'role' || name === 'roles') {
        value && (value = value.split(' ').filter((it) => it !== '')).length && addAllToSet((accum.role ??= new Set()), value)
      } else if (name === 'opts' || name === 'options') {
        value && (value = value.split(/,| /).filter((it) => it !== '')).length && addAllToSet((accum.opts ??= new Set()), value)
      } else {
        accum[name] = value
      }
      return accum
    }, initial)
  }

block_shorthand_attrs = anchor:block_anchor? style:block_style? shorthands:block_shorthand_attr* separator:$(!. / ' '* ',' ' '*)
  {
    const attrs = {}
    const value = separator ? text().slice(0, -separator.length) : text()
    if (!value) return attrs
    attrs['$1'] = value
    if (anchor) {
      attrs.id = anchor[0]
      if (anchor[1]) attrs.reftext = anchor[1]
    }
    if (style) attrs.style = style
    if (shorthands.length) {
      for (const [marker, val] of shorthands) {
        if (marker === '#') {
          attrs.id = val
        } else if (marker === '.') {
          ;(attrs.role ??= []).push(val)
        } else { // marker === '%'
          ;(attrs.opts ??= []).push(val)
        }
      }
    }
    return attrs
  }

block_anchor = '[' @idname @(',' ' '* @(valueOffset:offset value:$('\\' ('\\' / ']') / (!']' .))* { return valueToInlines(value, valueOffset, true, ']', locations['1']) }))? ']'

// Q what characters are allowed in a block style?
block_style = $([a-zA-Z_] [a-zA-Z0-9_-]*)

block_shorthand_attr = ('.' / '#' / '%') $(!'.' !'#' !'%' !',' !' ' .)+

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
