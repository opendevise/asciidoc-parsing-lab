{{
const { createContext, enterBlock, exitBlock, isBlockEnd, isCurrentList, isNestedSection, isNewList, toInlines } = require('#block-helpers')
const { parse: parseAttrlist } = require('#attrlist-parser')
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
  let { start, end } = range_ === true ? (eof = true) && range() : range_ || range()
  const { line: startLine, column: startCol } = peg$computePosDetails(start)
  const startDetails = { line: startLine, col: startCol }
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

function parseMetadata (attrlists, metadataStartOffset, metadataEndOffset) {
  if (!attrlists.length) return
  const cacheKey = metadataEndOffset
  if (cacheKey in metadataCache) return metadataCache[cacheKey]
  while (input[metadataEndOffset - 1] === '\n' && input[metadataEndOffset - 2] === '\n') metadataEndOffset--
  const attributes = {}
  const metadata = { attributes, options: [], roles: [] }
  for (const [attrlistOffset, attrlist] of attrlists) {
    if (!attrlist) continue
    const attrlistLocation = toSourceLocation(getLocation({ start: attrlistOffset, end: attrlistOffset + attrlist.length - 1 }))
    parseAttrlist(attrlist, { attributes: documentAttributes, inlineParser: { parse: parseInline }, locations: { 1: attrlistLocation[0] }, initial: attributes })
  }
  if ('opts' in attributes) attributes.opts = (metadata.options = [...attributes.opts]).join(',')
  if ('role' in attributes) attributes.role = (metadata.roles = [...attributes.role]).join(' ')
  metadata.location = toSourceLocation(getLocation({ start: metadataStartOffset, end: metadataEndOffset }))
  return (metadataCache[cacheKey] = metadata)
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

attribute_entry = ':' name:attribute_name ':' value:attribute_value? eol
  {
    return [name, value || '']
  }

// TODO permit non-ASCII letters in attribute name
attribute_name = !'-' @$[a-zA-Z0-9_-]+

attribute_value = space @$(!'\n' .)+

block_attribute_line = '[' @attrlist ']' eol

header = attributeEntriesAbove:attribute_entry* doctitleAndAttributeEntries:(doctitle attributeEntriesBelow:attribute_entry*)? &{ return doctitleAndAttributeEntries || attributeEntriesAbove.length } &eol
  {
    const attributes = {}
    const sourceLocation = toSourceLocation(getLocation())
    if (attributeEntriesAbove.length) {
      for (const [name, val] of attributeEntriesAbove) {
        if (!(name in documentAttributes)) documentAttributes[name] = attributes[name] = val
      }
    }
    let title
    if (doctitleAndAttributeEntries) {
      const [doctitle, locationsForDoctitleInlines] = doctitleAndAttributeEntries[0]
      title = parseInline(doctitle, { attributes: documentAttributes, locations: locationsForDoctitleInlines })
      // Q: set doctitle in header attributes too?
      //documentAttributes.doctitle = attributes.doctitle = doctitle
      documentAttributes.doctitle = doctitle
      const attributeEntriesBelow = doctitleAndAttributeEntries[1]
      if (attributeEntriesBelow.length) {
        for (const [name, val] of attributeEntriesBelow) {
          if (!(name in documentAttributes)) documentAttributes[name] = attributes[name] = val
        }
      }
      return { title, attributes, location: sourceLocation }
    }
    return { attributes, location: sourceLocation }
  }

doctitle = '=' space space* titleOffset:offset title:line
  {
    // Q: should this just return offset of title instead of locations for inlines?
    return [title, createLocationsForInlines(getLocation(), titleOffset - offset())]
  }

body = block*

// blocks = // does not include check for section; paragraph can just be paragraph
// blocks_in_section_body = // includes check for section; should start with !at_heading

block = lf* metadataStartOffset:offset metadata:(attrlists:(@block_attribute_line lf*)* metadataEndOffset:offset { return parseMetadata(attrlists, metadataStartOffset, metadataEndOffset) }) block:(!at_heading @(listing / example / sidebar / list / literal_paragraph / image / paragraph) / section_or_discrete_heading)
  {
    if (!metadata) return block
    const attributes = metadata.attributes
    if ('id' in attributes) block.id = attributes.id
    contentAttributeNames.forEach((name) => {
      let val
      if (name in attributes && (val = attributes[name]).constructor === Object) {
        block[name] = val.inlines
        attributes[name] = val.value
      }
    })
    return Object.assign(block, { metadata })
  }

// FIXME inlines in heading are being parsed multiple times when encountering sibling or parent section
section_or_discrete_heading = headingStartOffset:offset heading:heading blocks:(&{ return metadataCache[headingStartOffset]?.attributes.style === 'discrete' } / &{ return isNestedSection(context, heading) } @block*)
  {
    if (!blocks) return heading
    context.sectionStack.pop()
    Object.assign(heading, { name: 'section', blocks })
    if (blocks.length) heading.location = toSourceLocation(getLocation())
    return heading
  }

paragraph = lines:(!(block_attribute_line / any_compound_block_delimiter_line) @line)+
  {
    const location_ = getLocation()
    const contents = lines.join('\n')
    const inlines = parseInline(contents, { attributes: documentAttributes, locations: createLocationsForInlines(location_) })
    return { name: 'paragraph', type: 'block', inlines, location: toSourceLocation(location_) }
  }

literal_paragraph = lines:indented_line+
  {
    const indents = []
    for (const line of lines) indents.push(line.length - line.trimStart().length)
    const outdent = Math.min.apply(null, indents)
    const contents = lines.reduce((accum, l) => accum + '\n' + l.slice(outdent), '').slice(1)
    const metadata = metadataCache[offset()]
    if (metadata?.attributes.style === 'normal') {
      delete metadata.attributes.style
      const location_ = getLocation()
      const inlines = parseInline(contents, { attributes: documentAttributes, locations: createLocationsForInlines(location_, outdent) })
      return { name: 'paragraph', type: 'block', inlines, location: toSourceLocation(location_) }
    } else {
      const sourceLocation = toSourceLocation(getLocation())
      const inlinesSourceLocation = [Object.assign({}, sourceLocation[0], { col: sourceLocation[0].col + outdent }), sourceLocation[1]]
      const inlines = toInlines('text', contents, inlinesSourceLocation)
      return { name: 'literal', type: 'block', inlines, location: sourceLocation }
    }
  }

at_heading = '=' '='* space space* line

heading = marker:$('=' '='*) space space* titleOffset:offset title:line
  {
    const location_ = getLocation()
    const inlines = parseInline(title, { attributes: documentAttributes, locations: createLocationsForInlines(location_, titleOffset - offset()) })
    // Q: store marker instead of or in addition to level?
    return { name: 'heading', type: 'block', title: inlines, level: marker.length - 1, location: toSourceLocation(location_) }
  }

listing_delimiter_line = @$('-' '---' [-]*) eol

// FIXME pull lines out as separate rule to track location without having to hack location of parent
listing = (openingDelim:listing_delimiter_line { enterBlock(context, openingDelim) }) lines:(!(delim:listing_delimiter_line &{ return isBlockEnd(context, delim) }) @line_or_empty_line)* closingDelim:(@listing_delimiter_line / eof)
  {
    const delimiter = exitBlock(context)
    if (!closingDelim) console.log('unclosed listing block')
    // Q should start location include all block attribute lines? or should that information be on the attributedefs?
    const location_ = getLocation()
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
    return { name: 'listing', type: 'block', form: 'delimited', delimiter, inlines, location: toSourceLocation(location_) }
  }

example_delimiter_line = @$('=' '===' [=]*) eol

example = (openingDelim:example_delimiter_line &{ return enterBlock(context, openingDelim) }) blocks:(lf* @(heading / example / sidebar / list / paragraph))* closingDelim:(lf* @(example_delimiter_line / eof))
  {
    const delimiter = exitBlock(context)
    if (!closingDelim) console.log('unclosed example block')
    return { name: 'example', type: 'block', form: 'delimited', delimiter, blocks, location: toSourceLocation(getLocation()) }
  }

sidebar_delimiter_line = @$('*' '***' [*]*) eol

sidebar = (openingDelim:sidebar_delimiter_line &{ return enterBlock(context, openingDelim) }) blocks:(lf* @(heading / example / sidebar / list / paragraph))* closingDelim:(lf* @(sidebar_delimiter_line / eof))
  {
    const delimiter = exitBlock(context)
    if (!closingDelim) console.log('unclosed sidebar block')
    return { name: 'sidebar', type: 'block', form: 'delimited', delimiter, blocks, location: toSourceLocation(getLocation()) }
  }

// NOTE: use items:(@list_item @(lf* @list_item)*) to avoid having to check lf and list_marker on first item
list = &(marker:list_marker &{ return isNewList(context, marker) }) items:(lf* @list_item)+
  {
    const marker = context.listStack.pop()
    if (marker === '1.') {
      // TODO set this as start attribute
      let expected = parseInt(items[0].marker.slice(0, -1), 10)
      for (const item of items) {
        if (item.marker !== expected + '.') {
          console.log('list item index: expected ' + expected + ', got ' + item.marker.slice(0, -1))
        }
        expected += 1
      }
    }
    const variant = marker === '-' || marker[0] === '*' ? 'unordered' : 'ordered'
    return { name: 'list', type: 'block', variant, marker, items: items, location: toSourceLocation(getLocation()) }
  }

list_marker = @$('*' '*'* / '.' '.'* / '-' / [0-9]+ '.') space space* !eol

list_item_principal = firstLine:line wrappedLines:(!(block_attribute_line / list_continuation_line / list_marker / any_compound_block_delimiter_line) @line)*
  {
    const location_ = getLocation()
    const startCol = toSourceLocation(location_)[0].col
    const text = wrappedLines.length ? firstLine + '\n' + wrappedLines.join('\n') : firstLine
    return parseInline(text, { attributes: documentAttributes, locations: createLocationsForInlines(location_, startCol - 1) })
  }

list_continuation_line = '+' eol

// TODO process block attribute lines above attached blocks
list_item = marker:list_marker &{ return isCurrentList(context, marker) } principal:list_item_principal blocks:(list_continuation_line @(listing / example) / lf* @list)*
  {
    return { name: 'listItem', type: 'block', marker, principal, blocks, location: toSourceLocation(getLocation()) }
  }

image = 'image::' !space target:$(!'\n' !'[' .)+ '[' attrlist ']' eol
  {
    // TODO run parseAttrlist on attrlist[1]
    return { name: 'image', type: 'block', form: 'macro', target, location: toSourceLocation(getLocation()) }
  }

any_compound_block_delimiter_line = example_delimiter_line / sidebar_delimiter_line

offset = ''
  {
    return peg$currPos
  }

line = @$(!'\n' .)+ eol

line_or_empty_line = line / lf @''

indented_line = @$(space (!'\n' .)+) eol

attrlist = !space @offset @$(!(lf / space? ']' eol) .)*

space = ' '

lf = '\n'

eof = !.

eol = '\n' / !.
