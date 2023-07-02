{{
const { createContext, enterBlock, exitBlock, exitList, exitSection, isBlockEnd, isCurrentList, isNestedSection, isNewList, toInlines } = require('#block-helpers')
const inlinePreprocessor = require('#inline-preprocessor')
const { parse: parseAttrlist } = require('#attrlist-parser')
const ADMONITION_STYLES = { CAUTION: 'caution', IMPORTANT: 'important', NOTE: 'note', TIP: 'tip', WARNING: 'warning' }
const MAX_ADMONITION_STYLE_LENGTH = Object.keys(ADMONITION_STYLES).reduce((max, it) => it.length > max ? it.length : max, 0)
}}
{
const {
  attributes: documentAttributes = {},
  contentAttributeNames = ['title', 'reftext', 'caption', 'citetitle', 'attribution'],
  locations,
} = options
const context = createContext()
const parseInline = (options.inlineParser ?? require('#block-default-inline-parser')).parse
const metadataCache = {}

function getLocation (range_) {
  let eof
  let { start, end = start + (range_.text || '.').length - 1 } = range_ === true ? (eof = true) && range() : range_ || range()
  const { line: startLine, column: startCol } = peg$computePosDetails(start)
  const startDetails = { line: startLine, col: !end || input[start] === '\n' ? 0 : startCol }
  if (end === start) return [startDetails, startDetails]
  let hasEol
  if (eof) {
    ;(hasEol = input[input.length - 1] === '\n') || end--
  } else if (input[--end] === '\n') { // NOTE lf is the end of the block in this case
    end--
  }
  if (end === start) return [startDetails, startDetails]
  const { line: endLine, column: endCol } = peg$computePosDetails(end)
  return [startDetails, { line: endLine, col: hasEol ? 0 : endCol }]
}

function toSourceLocation (location) {
  if (!locations) return location
  const [start, end] = location
  let originalStart = locations[start.line]
  if (start.col !== 1) originalStart = Object.assign({}, originalStart, { col: originalStart.col + (start.col - 1) })
  if (start === end) return [originalStart, originalStart]
  let originalEnd = locations[end.line]
  if (end.col !== 1) originalEnd = Object.assign({}, originalEnd, { col: originalEnd.col + (end.col - 1) })
  return [originalStart, originalEnd]
}

function createLocationsForInlines ([start, end = start], offset) {
  const mapping = {} // maps line numbers to location objects
  let localLine = 1
  if (locations) {
    for (let line = start.line, lastLine = end.line; line <= lastLine; line++) mapping[localLine++] = locations[line]
  } else {
    for (let line = start.line, lastLine = end.line; line <= lastLine; line++) mapping[localLine++] = { line, col: 1 }
  }
  if (offset) (mapping[1] = Object.assign({}, mapping[1])).col += offset
  return mapping
}

function parseBlockMetadata (attrlists, metadataStartOffset, metadataEndOffset) {
  if (!attrlists.length) return
  const cacheKey = metadataEndOffset
  if (cacheKey in metadataCache) return metadataCache[cacheKey]
  while (input[metadataEndOffset - 1] === '\n' && input[metadataEndOffset - 2] === '\n') metadataEndOffset--
  const attributes = {}
  for (const [marker, attrlistOffset, attrlist] of attrlists) {
    if (!attrlist) continue
    const location_ = getLocation({ start: attrlistOffset, text: attrlist })
    if (marker === '.') {
      // NOTE attribute references will be resolved in this line after all block attribute lines
      const resolveValue = function (value, parseInlineOpts, asInlines) {
        return asInlines ? { value, inlines: parseInline(value, parseInlineOpts) } : value
      }
      // NOTE this is slightly faked since location_ will already account for column offset, but it still works
      attributes.title = resolveValue.bind(null, attrlist, { attributes: documentAttributes, locations: createLocationsForInlines(location_, 1) })
    } else {
      parseAttrlist(attrlist, { attributes: documentAttributes, initial: attributes, inlineParser: { parse: parseInline }, locations: { 1: toSourceLocation(location_)[0] }, startRule: 'block_attrlist_with_shorthands' })
    }
  }
  const metadataLocation = toSourceLocation(getLocation({ start: metadataStartOffset, end: metadataEndOffset }))
  return (metadataCache[cacheKey] = { attributes, options: [], roles: [], location: metadataLocation })
}

function applyBlockMetadata (block, metadata, posattrs) {
  if (!metadata) return block
  const attributes = metadata.attributes
  const names = Object.keys(attributes)
  if (posattrs) {
    let posIdx = 0
    for (const name of posattrs) {
      const posKey = `$${++posIdx}`
      if (name == null) continue
      if (!(posKey in attributes)) continue
      // Q: should existing named attribute be allowed to take precedence? (this has never been the case)
      if (name in attributes) names.splice(names.indexOf(name), 1)
      names.splice(names.indexOf(posKey), 0, name)
      const valueObject = attributes[name] = attributes[posKey]
      // NOTE remap value as deferred function to avoid having to resolve again for positional attribute
      if (valueObject.constructor === Function) attributes[posKey] = () => attributes[name]
    }
  }
  if ('id' in attributes) block.id = attributes.id
  attributes.opts &&= (metadata.options = [...attributes.opts]).join(',')
  attributes.role &&= (metadata.roles = [...attributes.role]).join(' ')
  for (const name of names) {
    const valueObject = attributes[name]
    if (valueObject.constructor !== Function) continue
    if (contentAttributeNames.includes(name)) {
      ;({ value: attributes[name], inlines: block[name] } = valueObject(true))
    } else {
      attributes[name] = valueObject()
    }
  }
  return Object.assign(block, { metadata })
}
}
// TODO if surrounding lf are not part of document, group inner two rules as a new rule
//document = lf* header:header? blocks:body lf*
document = lf* header:header? blocks:body .*
  {
    const node = { name: 'document', type: 'block' }
    if (header) {
      node.attributes = header.attributes
      delete header.attributes
      node.header = header
    }
    return Object.assign(node, { blocks, location: toSourceLocation(getLocation(true)) })
  }

attribute_entry = ':' negatedPrefix:'!'? name:attribute_name negatedSuffix:'!'? ':' value:attribute_value? eol
  {
    return [name, negatedPrefix || negatedSuffix ? false : value || '']
  }

// TODO permit non-ASCII letters in attribute name
attribute_name = !'-' @$[a-zA-Z0-9_-]+

attribute_value = space @$(!lf .)+

header = attributeEntriesAbove:attribute_entry* doctitleAndAttributeEntries:(doctitle author_info_line? attributeEntriesBelow:attribute_entry*)? &{ return doctitleAndAttributeEntries || attributeEntriesAbove.length }
  {
    const attributes = {}
    const header = {}
    const sourceLocation = toSourceLocation(getLocation())
    if (attributeEntriesAbove.length) {
      for (const [name, val] of attributeEntriesAbove) {
        if (name in documentAttributes && !(name in attributes)) continue
        if (val === false && !(attributes[name] = val)) {
          delete documentAttributes[name]
        } else {
          documentAttributes[name] = attributes[name] = val ? inlinePreprocessor(val, { attributes: documentAttributes, mode: 'attributes', sourceMapping: false }).input : val
        }
      }
    }
    if (doctitleAndAttributeEntries) {
      const [[doctitle, locationsForDoctitleInlines], authors, attributeEntriesBelow] = doctitleAndAttributeEntries
      header.title = parseInline(doctitle, { attributes: documentAttributes, locations: locationsForDoctitleInlines })
      // Q: set doctitle in header attributes too? set even if locked??
      //documentAttributes.doctitle = attributes.doctitle = doctitle
      documentAttributes.doctitle = doctitle
      if (authors) {
        documentAttributes.author = attributes.author = authors[0].fullname
        const address = authors[0].address
        if (address) documentAttributes.email = attributes.email = address
        documentAttributes.authors = attributes.authors = authors.map(({ fullname }) => fullname).join(', ')
        header.authors = authors
      }
      if (attributeEntriesBelow.length) {
        for (const [name, val] of attributeEntriesBelow) {
          if (name in documentAttributes && !(name in attributes)) continue
          if (val === false && !(attributes[name] = val)) {
            delete documentAttributes[name]
          } else {
            documentAttributes[name] = attributes[name] = val ? inlinePreprocessor(val, { attributes: documentAttributes, mode: 'attributes', sourceMapping: false }).input : val
          }
        }
      }
    }
    return Object.assign(header, { attributes, location: sourceLocation })
  }

doctitle = '=' space space* titleOffset:offset title:line
  {
    // Q: should this just return offset of title instead of locations for inlines?
    return [title, createLocationsForInlines(getLocation(), titleOffset - offset())]
  }

author_info_line = @author_info_item|1.., '; '| eol

// Q: are attribute references permitted? if so, how do they work?
author_info_item = names:author_name|1..3, space| address:(' <' @$(!'>' !lf .)+ '>')?
  {
    const info = {}
    names = names.filter((name) => name).map((name) => ~name.indexOf('_') ? name.replace(/_/g, ' ') : name)
    const numNames = names.length
    let fullname, firstname, middlename, lastname
    if (numNames > 2) {
      ;([firstname, middlename, lastname] = names)
      fullname = firstname + ' ' + middlename + ' ' + lastname
      const initials = firstname[0] + middlename[0] + lastname[0]
      Object.assign(info, { fullname, initials, firstname, middlename, lastname })
    } else if (numNames > 1) {
      ;([firstname, lastname] = names)
      fullname = firstname + ' ' + lastname
      const initials = firstname[0] + lastname[0]
      Object.assign(info, { fullname, initials, firstname, lastname })
    } else {
      fullname = firstname = names[0]
      const initials = firstname[0]
      Object.assign(info, { fullname, initials, firstname })
    }
    if (address) info.address = address
    return info
  }

author_name = $([a-zA-Z0-9] ('.' / [a-zA-Z0-9_'-]*))

body = section_block*

// Q: should empty lines be permitted in metadata on block attached to list item?
block_metadata = lf* metadataStartOffset:offset attrlists:(@(block_attribute_line / block_title_line) lf*)* metadataEndOffset:offset
  {
    return parseBlockMetadata(attrlists, metadataStartOffset, metadataEndOffset)
  }

block_attribute_line = @'[' @offset @attrlist ']' eol

// NOTE don't match line that starts with '. ' or '.. ' (which could be a list marker) or '...' (which could be a literal block delimiter or list marker)
block_title_line = @'.' @offset @$('.'? (!lf !' ' !'.' .) (!lf .)*) eol

// NOTE !heading is checked first since section_or_discrete_heading rule will fail at ancestor section, but should not then match a different rule
section_block = block_metadata @(!heading @(listing / example / sidebar / list / indented / image / paragraph) / section_or_discrete_heading)

block = block_metadata @(discrete_heading / listing / example / sidebar / list / indented / image / paragraph)

section_or_discrete_heading = headingStartOffset:offset headingRecord:heading blocks:(&{ return metadataCache[headingStartOffset]?.attributes.style === 'discrete' } / &{ return isNestedSection(context, headingRecord[0].length - 1) } @section_block*)
  {
    const [marker, titleOffset, title] = headingRecord
    const location_ = getLocation()
    const offset_ = offset()
    const inlines = parseInline(title, { attributes: documentAttributes, locations: createLocationsForInlines(location_, titleOffset - offset_) })
    // Q: store marker instead of or in addition to level?
    const node = { name: 'heading', type: 'block', title: inlines, level: marker.length - 1, location: toSourceLocation(location_) }
    if (blocks) {
      exitSection(context)
      Object.assign(node, { name: 'section', blocks })
    }
    return applyBlockMetadata(node, metadataCache[offset_])
  }

discrete_heading = headingRecord:heading
  {
    const [marker, titleOffset, title] = headingRecord
    const location_ = getLocation()
    const offset_ = offset()
    const inlines = parseInline(title, { attributes: documentAttributes, locations: createLocationsForInlines(location_, titleOffset - offset_) })
    // Q: store marker instead of or in addition to level?
    const node = { name: 'heading', type: 'block', title: inlines, level: marker.length - 1, location: toSourceLocation(location_) }
    return applyBlockMetadata(node, metadataCache[offset_])
  }

heading = @$('=' '='*) space space* @offset @line

// TODO in order to enable list matching shorthand, must ensure this rule is only called when all other syntax has been exhausted
//paragraph = lines:line|1.., !(block_attribute_line / any_block_delimiter_line)|
paragraph = lines:(!(block_attribute_line / any_block_delimiter_line) @line)+
  {
    const location_ = getLocation()
    const metadata = metadataCache[offset()]
    const firstLine = lines[0]
    let style, admonitionVariant, inlinesOffset
    if ((style = metadata?.attributes.style)) {
      admonitionVariant = ADMONITION_STYLES[style]
    } else if (firstLine.length > MAX_ADMONITION_STYLE_LENGTH + 2 && ~(inlinesOffset = firstLine.indexOf(': ')) &&
        inlinesOffset <= MAX_ADMONITION_STYLE_LENGTH && (admonitionVariant = ADMONITION_STYLES[firstLine.slice(0, inlinesOffset)])) {
      lines[0] = firstLine.slice((inlinesOffset += 2))
    } else {
      inlinesOffset = 0
    }
    const inlines = parseInline(lines.join('\n'), { attributes: documentAttributes, locations: createLocationsForInlines(location_, inlinesOffset) })
    const sourceLocation = toSourceLocation(location_)
    let node = { name: 'paragraph', type: 'block', inlines, location: sourceLocation }
    if (admonitionVariant) {
      // Q: should location for paragraph start after admonition label?
      node = { name: 'admonition', type: 'block', form: 'paragraph', variant: admonitionVariant, blocks: [node], location: sourceLocation }
    }
    return applyBlockMetadata(node, metadata)
  }

indented = lines:indented_line+
  {
    const indents = []
    for (const line of lines) indents.push(line.length - line.trimStart().length)
    const outdent = Math.min.apply(null, indents)
    const contents = lines.reduce((accum, l) => accum + '\n' + l.slice(outdent), '').slice(1)
    const metadata = metadataCache[offset()]
    const location_ = getLocation()
    let node
    // Q should we allow "paragraph" as alternative to "normal"?
    if (metadata?.attributes.style === 'normal') {
      const inlines = parseInline(contents, { attributes: documentAttributes, locations: createLocationsForInlines(location_, outdent) })
      node = { name: 'paragraph', type: 'block', form: 'indented', inlines, location: toSourceLocation(location_) }
    } else {
      const sourceLocation = toSourceLocation(location_)
      const inlinesSourceLocation = [Object.assign({}, sourceLocation[0], { col: sourceLocation[0].col + outdent }), sourceLocation[1]]
      const inlines = toInlines('text', contents, inlinesSourceLocation)
      node = { name: 'literal', type: 'block', form: 'indented', inlines, location: sourceLocation }
    }
    return applyBlockMetadata(node, metadata)
  }

listing_delimiter_line = @$('-' '-'|3..|) eol

// FIXME pull lines out as separate rule to track location without having to hack location of parent
listing = (openingDelim:listing_delimiter_line { enterBlock(context, openingDelim) }) lines:(!(delim:listing_delimiter_line &{ return isBlockEnd(context, delim) }) @line_or_empty_line)* closingDelim:(@listing_delimiter_line / eof)
  {
    const delimiter = exitBlock(context)
    if (!closingDelim && options.showWarnings) console.warn('unclosed listing block')
    const location_ = getLocation(closingDelim ? undefined : true)
    const inlines = []
    if (lines.length) {
      const firstLine = lines[0]
      const contentsLocation = [
        { line: location_[0].line + 1, col: (firstLine ? 1 : 0) },
        { line: location_[1].line - (closingDelim ? 1 : 0), col: lines[lines.length - 1].length },
      ]
      const value = lines.length > 1 ? lines.join('\n') : (firstLine || '\n')
      inlines.push(toInlines('text', value, toSourceLocation(contentsLocation))[0])
    }
    const node = { name: 'listing', type: 'block', form: 'delimited', delimiter, inlines, location: toSourceLocation(location_) }
    return applyBlockMetadata(node, metadataCache[offset()])
  }

example_delimiter_line = @$('=' '='|3..|) eol

example = (openingDelim:example_delimiter_line &{ return enterBlock(context, openingDelim) }) blocks:block* closingDelim:(lf* @(example_delimiter_line / eof))
  {
    const delimiter = exitBlock(context)
    let name = 'example'
    let style, admonitionVariant
    const metadata = metadataCache[offset()]
    if ((style = metadata?.attributes.style) && (admonitionVariant = ADMONITION_STYLES[style])) name = 'admonition'
    if (!closingDelim && options.showWarnings) console.warn(`unclosed ${name} block`)
    const node = { name, type: 'block', form: 'delimited', delimiter, variant: admonitionVariant, blocks, location: toSourceLocation(getLocation(closingDelim ? undefined : true)) }
    if (!admonitionVariant) delete node.variant
    return applyBlockMetadata(node, metadata)
  }

sidebar_delimiter_line = @$('*' '*'|3..|) eol

sidebar = (openingDelim:sidebar_delimiter_line &{ return enterBlock(context, openingDelim) }) blocks:block* closingDelim:(lf* @(sidebar_delimiter_line / eof))
  {
    const delimiter = exitBlock(context)
    if (!closingDelim && options.showWarnings) console.warn('unclosed sidebar block')
    const node = { name: 'sidebar', type: 'block', form: 'delimited', delimiter, blocks, location: toSourceLocation(getLocation(closingDelim ? undefined : true)) }
    return applyBlockMetadata(node, metadataCache[offset()])
  }

list = &(marker:list_marker &{ return isNewList(context, marker) }) items:list_item|1.., lf*|
  {
    const marker = exitList(context)
    if (marker === '1.') {
      // TODO set this as start attribute
      let expected = parseInt(items[0].marker.slice(0, -1), 10)
      for (const item of items) {
        if (item.marker !== expected + '.' && options.showWarnings) {
          console.warn('list item index: expected ' + expected + ', got ' + item.marker.slice(0, -1))
        }
        expected++
      }
    }
    const variant = marker === '-' || marker[0] === '*' ? 'unordered' : 'ordered'
    const node = { name: 'list', type: 'block', variant, marker, items: items, location: toSourceLocation(getLocation()) }
    return applyBlockMetadata(node, metadataCache[offset()])
  }

list_marker = space* @$('*' '*'* / '.' '.'* / '-' / [0-9]+ '.') space space* !eol

list_item_principal = lines:line|1.., !(block_attribute_line / list_continuation_line / list_marker / any_block_delimiter_line)|
  {
    const location_ = getLocation()
    const startCol = toSourceLocation(location_)[0].col
    return parseInline(lines.join('\n'), { attributes: documentAttributes, locations: createLocationsForInlines(location_, startCol - 1) })
  }

list_continuation_line = '+' eol

// TODO process block attribute lines above attached blocks
// Q should block match after list continuation end with '?', or should last alternative be '!.'?
// lf* above block rule will get absorbed into attached_block rule
list_item = marker:list_marker &{ return isCurrentList(context, marker) } principal:list_item_principal blocks:(list_continuation_line lf* @block? / lf* @(list / indented))*
  {
    if (blocks.length && blocks[blocks.length - 1] == null) blocks.pop()
    return { name: 'listItem', type: 'block', marker, principal, blocks, location: toSourceLocation(getLocation()) }
  }

image = 'image::' !space target:$(!lf !'[' .)+ '[' attrlistOffset:offset attrlist:attrlist ']' eol
  {
    let metadata = metadataCache[offset()]
    if (attrlist) {
      const initial = (metadata ??= { attributes: {}, options: [], roles: [] }).attributes
      parseAttrlist(attrlist, { attributes: documentAttributes, initial, inlineParser: { parse: parseInline }, locations: { 1: toSourceLocation(getLocation({ start: attrlistOffset, text: attrlist }))[0] } })
    }
    target = inlinePreprocessor(target, { attributes: documentAttributes, mode: 'attributes', sourceMapping: false }).input
    const node = { name: 'image', type: 'block', form: 'macro', target, location: toSourceLocation(getLocation()) }
    return applyBlockMetadata(node, metadata, ['alt', 'width', 'height'])
  }

any_block_delimiter_line = listing_delimiter_line / example_delimiter_line / sidebar_delimiter_line

line = @$(!lf .)+ eol

line_or_empty_line = line / lf @''

indented_line = @$(space (!lf .)+) eol

attrlist = !space @$(!(lf / space? ']' eol) .)*

space = ' '

lf = '\n'

eof = !.

eol = '\n' / !.

offset = ''
  {
    return peg$currPos
  }
