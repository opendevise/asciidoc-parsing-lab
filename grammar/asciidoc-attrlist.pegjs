{{
const inlinePreprocessor = require('#inline-preprocessor')
const { addAllToSet } = require('#util')
}}
{
if (!input) return {}
const { attributes: documentAttributes = {}, locations = { 1: { line: 1, col: 1 } }, initial = {} } = options
const { input: preprocessedInput, sourceMapping } = inlinePreprocessor(input, { attributes: documentAttributes, mode: 'attributes' })
if (!preprocessedInput) return {}
if (sourceMapping) input = preprocessedInput
const parseInline = (options.inlineParser ?? require('#block-default-inline-parser')).parse

function createValueResolver({ value, offset: valueOffset, enclosureChar }, sourceMapping_, startLocation) {
  return resolveValue.bind(null, value, valueOffset, enclosureChar, sourceMapping_, startLocation)
}

function updateAttributes (accum, entries, posIdx = 0) {
  if (!entries) return accum
  for (let [name, valueRecord] of entries) {
    let [enclosureChar, offset_, value] = valueRecord
    posIdx++
    if (name == null) {
      if (value) {
        const posKey = `$${posIdx}`
        if (posKey in accum) delete accum[posKey]
        accum[posKey] = createValueResolver({ enclosureChar, offset: offset_, value }, sourceMapping, locations['1'])
      }
    } else if (name === 'id' || name === 'style') {
      accum[name] = value
    } else if (name === 'role' || name === 'roles') {
      value && (value = value.split(' ').filter((it) => it !== '')).length && addAllToSet((accum.role ??= new Set()), value)
    } else if (name === 'opts' || name === 'options') {
      value && (value = value.split(/,| /).filter((it) => it !== '')).length && addAllToSet((accum.opts ??= new Set()), value)
    } else {
      if (name in accum) delete accum[name]
      accum[name] = createValueResolver({ enclosureChar, offset: offset_, value }, sourceMapping, locations['1'])
    }
  }
  return accum
}

function resolveValue (value, valueOffset, enclosureChar, sourceMapping_, startLocation, asInlines) {
  if (asInlines) return valueToInlines(value, valueOffset, enclosureChar, sourceMapping_, startLocation)
  if (enclosureChar && ~value.indexOf('\\')) {
    return value.replace(new RegExp(`\\\\+(?=${enclosureChar}|$)`, 'g'), (match) => match.slice(0, Math.floor(match.length / 2)))
  }
  return value
}

// returns { value, inlines }, where value is the result after resolving any escaped enclosure chars
function valueToInlines (value, valueOffset, enclosureChar, sourceMapping_, startLocation) {
  let inlines = []
  if (!value) return { value, inlines }
  if (enclosureChar && enclosureChar !== '"') {
    if (sourceMapping_) sourceMapping_ = sourceMapping_.slice(valueOffset, valueOffset + value.length)
    if (enclosureChar && ~value.indexOf('\\')) {
      sourceMapping_ ??= [...Array(value.length)].map((_, offset) => ({ offset: offset + valueOffset }))
      const escapes = {}
      value = value.replace(new RegExp(`\\\\+(?=${enclosureChar}|$)`, 'g'), (match, idx) => {
        let numBackslashes = match.length
        if (numBackslashes % 2) escapes[idx - 1 + numBackslashes--] = true
        if (!numBackslashes) return ''
        for (let i = 0; i < numBackslashes; i += 2) escapes[i + idx + 1] = true
        return match.slice(0, numBackslashes / 2)
      })
      if (Object.keys(escapes).length) sourceMapping_ = sourceMapping_.filter((it, idx) => !escapes[idx])
    }
    const locationsForInlines = { 1: Object.assign({}, startLocation, { col: startLocation.col + (sourceMapping_ ? 0 : valueOffset) }) }
    inlines = parseInline(value, { locations: locationsForInlines, preprocessorMode: 'passthroughs', sourceMapping: sourceMapping_ })
  } else {
    let valueStartOffset, valueEndOffset
    if (sourceMapping_) {
      if (Array.isArray((valueStartOffset = sourceMapping_[valueOffset].offset))) valueStartOffset = valueStartOffset[0]
      if (Array.isArray((valueEndOffset = sourceMapping_[valueOffset + value.length - 1].offset))) valueEndOffset = valueEndOffset[1]
    } else {
      valueEndOffset = (valueStartOffset = valueOffset) + value.length - 1
    }
    if (enclosureChar && ~value.indexOf('\\')) {
      value = value.replace(new RegExp(`\\\\+(?=${enclosureChar}|$)`, 'g'), (match) => '\\'.repeat(Math.floor(match.length / 2)))
    }
    const inlinesSourceLocation = [
      Object.assign({}, startLocation, { col: startLocation.col + valueStartOffset }),
      Object.assign({}, startLocation, { col: startLocation.col + valueEndOffset }),
    ]
    inlines = [{ type: 'string', name: 'text', value, location: inlinesSourceLocation }]
  }
  return { value, inlines }
}
}
block_attrlist = entries:block_attrs
  {
    return updateAttributes(initial, entries)
  }

block_attrlist_with_shorthands = shorthandAttrs:block_shorthand_attrs? entries:(!. / block_attrs)
  {
    let posIdx
    if ((posIdx = shorthandAttrs ? 1 : 0) && '$1' in shorthandAttrs) {
      if ('reftext' in shorthandAttrs) {
        if ('reftext' in initial) delete initial.reftext
        shorthandAttrs.reftext = createValueResolver(shorthandAttrs.reftext, sourceMapping, locations['1'])
      }
      shorthandAttrs.role &&= addAllToSet((initial.role ?? new Set()), shorthandAttrs.role)
      shorthandAttrs.opts &&= addAllToSet((initial.opts ?? new Set()), shorthandAttrs.opts)
      Object.assign(initial, shorthandAttrs)
    }
    return updateAttributes(initial, entries, posIdx)
  }

block_shorthand_attrs = anchor:block_anchor? style:block_style? shorthands:block_shorthand_attr* separator:$(!. / ' '* ',' ' '*)
  {
    const attrs = {}
    const value = input.substring(peg$savedPos, peg$currPos - (separator?.length ?? 0))
    if (!value) return attrs
    attrs['$1'] = value
    if (anchor) {
      attrs.id = anchor[0]
      if (anchor[1]) attrs.reftext = anchor[1]
    }
    if (style) attrs.style = style
    if (!shorthands.length) return attrs
    for (const [marker, val] of shorthands) {
      if (marker === '#') {
        attrs.id = val
      } else if (marker === '.') {
        ;(attrs.role ??= []).push(val)
      } else { // marker === '%'
        ;(attrs.opts ??= []).push(val)
      }
    }
    return attrs
  }

block_anchor = '[' @idname @(',' ' '* @(valueOffset:offset value:$('\\' ('\\' / ']') / (!']' .))* { return { enclosureChar: ']', offset: valueOffset, value } }))? ']'

// Q what characters are allowed in a block style?
block_style = $([a-zA-Z_] [a-zA-Z0-9_-]*)

block_shorthand_attr = ('.' / '#' / '%') $(!('.' / '#' / '%' / ',' / ' ') .)+

block_attrs = block_attr|.., ',' ' '* / ' '+ (',' ' '*)?|

block_attr = @name:(@block_attr_name ('=' !' ' / ' '* '=' ' '*))? @block_attr_val

// TODO support unicode alpha
block_attr_name = $([a-zA-Z_] [a-zA-Z0-9_-]*)

// TODO support unicode alpha
idname = $([a-zA-Z_:] [a-zA-Z0-9_\-:.]*)

block_attr_val = double_quoted_attr_val / single_quoted_attr_val / unquoted_attr_val

double_quoted_attr_val = @'"' @offset @$('\\' ('\\' / '"') / (!'"' .))* '"' &(!. / ',' / ' ')

single_quoted_attr_val = @'\'' @offset @$('\\' ('\\' / '\'') / (!'\'' .))* '\'' &(!. / ',' / ' ')

unquoted_attr_val = '' offset $(!(',' / ' ') . / ' '+ !',' &.)*

offset = ''
  {
    return peg$currPos
  }
