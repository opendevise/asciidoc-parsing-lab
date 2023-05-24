{{
const { createContext, enterBlock, exitBlock, isBlockEnd, isCurrentList, isNestedSection, isNewList, toInlines } = require('#block-helpers')
}}
{
const { attributes: documentAttributes = {}, locations } = options
const context = createContext()
const parseInline = (options.inlineParser ?? require('#block-default-inline-parser')).parse
const metadataCache = {}

function getLocation (range_) {
  let eof
  const { start, end } = range_ === true ? (eof = true) && range() : range_ || range()
  const { line: startLine, column: startCol } = peg$computePosDetails(start)
  const startDetails = { line: startLine, col: startCol }
  if (end === start) return [startDetails, startDetails]
  if (eof) {
    const { line: endLine, column: endCol } = peg$computePosDetails(end)
    return [startDetails, { line: endLine, col: endCol - 1 }]
  } else {
    const { line: endLine, column: endCol } = peg$computePosDetails(end - (end < input.length || (input[end - 1] ?? '\n') === '\n' ? 2 : 1))
    return [startDetails, { line: endLine, col: endCol }]
  }
}

function toSourceLocation (location) {
  if (!locations) return location
  const [start, end] = location
  const originalStart = Object.assign({}, locations[start.line])
  originalStart.col += start.col - 1
  if (start === end) return [originalStart, originalStart]
  // FIXME end fallback needed for newline at end of document added by include
  const originalEnd = Object.assign({}, locations[end.line] || locations[end.line - 1])
  originalEnd.col += end.col - 1
  return [originalStart, originalEnd]
}

function createLocationsForInlines ([start, end = start], startCol = 1) {
  const mapping = {} // maps line numbers to location objects
  let localLine = 1
  if (locations) {
    for (let line = start.line, lastLine = end.line; line <= lastLine; line++) mapping[localLine++] = locations[line]
  } else {
    for (let line = start.line, lastLine = end.line; line <= lastLine; line++) mapping[localLine++] = { line, col: 1 }
  }
  if (startCol > 1) (mapping[1] = Object.assign({}, mapping[1])).col += startCol - 1
  return mapping
}
}
// TODO if surrounding lf are not part of document, group inner two rules as a new rule
document = lf* header:header? blocks:body lf*
  {
    const node = { name: 'document', type: 'block' }
    if (header) {
      node.attributes = header.attributes
      delete header.attributes
      node.header = header
    }
    return Object.assign(node, { blocks, location: toSourceLocation(getLocation(true)) })
  }

attribute_entry = ':' name:attribute_name ':' value:attribute_value eol
  {
    return [name, value]
  }

// TODO permit non-ASCII letters in attribute name
attribute_name = !'-' @$[a-zA-Z0-9_-]+

attribute_value = (space @$[^\n]+ / '')

block_attribute_line = '[' @attrlist ']' eol

// TODO allow doctitle to be optional
header = attributeEntriesAbove:attribute_entry* titleOffset:grab_offset title:doctitle attributeEntriesBelow:attribute_entry* &eol
  {
    const attributes = {}
    for (const attributeEntries of [attributeEntriesAbove, attributeEntriesBelow]) {
      if (!attributeEntries.length) continue
      for (const [name, val] of attributeEntries) {
        if (!(name in documentAttributes)) documentAttributes[name] = attributes[name] = val
      }
    }
    // FIXME need to move this between entries above/below so it is available to below
    documentAttributes.doctitle = title
    const titleLocation = getLocation({ start: titleOffset, end: titleOffset + title.length })
    const titleInlines = parseInline(title, { attributes: documentAttributes, locations: createLocationsForInlines(titleLocation, 3) })
    return { title: titleInlines, attributes, location: toSourceLocation(getLocation()) }
  }

// TODO be more strict about doctitle chars; namely require a non-space
doctitle = '= ' @line

body = block*

// blocks = // does not include check for section; paragraph can just be paragraph
// blocks_in_section_body = // includes check for section; should start with !at_heading

block = lf* metadataStart:grab_offset metadata:(attrlists:(@block_attribute_line lf*)* metadataEnd:grab_offset {
    // TODO move this logic to a helper function or grammar rule
    if (!attrlists.length) return undefined
    const cacheKey = metadataEnd
    while (input[metadataEnd - 1] === '\n' && input[metadataEnd - 2] === '\n') metadataEnd--
    const attributes = {}
    const options_ = []
    for (const attrlist of attrlists) {
      if (!attrlist) continue
      // FIXME this is a quick hack
      let positionalIndex = 0
      attrlist.split(',').forEach((it) => {
        let equalsIdx = it.indexOf('=')
        if (~equalsIdx) {
          const name = it.slice(0, equalsIdx)
          const value = it.slice(equalsIdx + 1)
          if (name === 'opts' || name === 'options') {
            for (const opt of value.split(',')) {
              if (!~options_.indexOf(opt)) options_.push(opt)
            }
          } else if (name === 'role' && 'role' in attributes) {
            if (value) attributes.role += ' ' + value
          } else {
            attributes[name] = value
          }
        } else {
          attributes[++positionalIndex] = it
          if (positionalIndex === 1) attributes.style = it
        }
      })
    }
    return (metadataCache[cacheKey] = { attributes, options: options_, location: toSourceLocation(getLocation({ start: metadataStart, end: metadataEnd })) })
  }) block:(!at_heading @(listing / example / sidebar / list / literal_paragraph / image / paragraph) / section_or_discrete_heading)
  {
    return metadata ? Object.assign(block, { metadata }) : block
  }

// FIXME inlines in heading are being parsed multiple times when encountering sibling or parent section
section_or_discrete_heading = headingStart:grab_offset heading:heading blocks:(&{ return metadataCache[headingStart]?.attributes.style === 'discrete' } / &{ return isNestedSection(context, heading) } @block*)
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
      const inlines = parseInline(contents, { attributes: documentAttributes, locations: createLocationsForInlines(location_, outdent + 1) })
      return { name: 'paragraph', type: 'block', inlines, location: toSourceLocation(location_) }
    } else {
      const sourceLocation = toSourceLocation(getLocation())
      const inlinesSourceLocation = [Object.assign({}, sourceLocation[0], { col: sourceLocation[0].col + outdent }), sourceLocation[1]]
      const inlines = toInlines('text', contents, inlinesSourceLocation)
      return { name: 'literal', type: 'block', inlines, location: sourceLocation }
    }
  }

at_heading = '='+ space line

heading = marker:'='+ space title:line
  {
    const location_ = getLocation()
    const inlines = parseInline(title, { attributes: documentAttributes, locations: createLocationsForInlines(location_, marker.length + 2) })
    // Q: store marker instead of or in addition to level?
    return { name: 'heading', type: 'block', title: inlines, level: marker.length - 1, location: toSourceLocation(location_) }
  }

listing_delimiter = @$('----' [-]*) eol

// FIXME pull lines out as separate rule to track location without having to hack location of parent
listing = (openingDelim:listing_delimiter { enterBlock(context, openingDelim) }) lines:(!(delim:listing_delimiter &{ return isBlockEnd(context, delim) }) @line_or_empty_line)* closingDelim:(@listing_delimiter / eof)
  {
    const delimiter = exitBlock(context)
    if (!closingDelim) console.log('unclosed listing block')
    // Q should start location include all block attribute lines? or should that information be on the attributedefs?
    const location_ = getLocation()
    const inlines = []
    if (lines.length) {
      const contentsLocation = [
        { line: location_[0].line + 1, col: 1 },
        { line: location_[1].line - (closingDelim ? 1 : 0), col: lines[lines.length - 1].length },
      ]
      inlines.push(toInlines('text', lines.join('\n'), toSourceLocation(contentsLocation))[0])
    }
    return { name: 'listing', type: 'block', form: 'delimited', delimiter, inlines, location: toSourceLocation(location_) }
  }

example_delimiter_line = @$('====' [=]*) eol

example = (openingDelim:example_delimiter_line &{ return enterBlock(context, openingDelim) }) blocks:(lf* @(heading / example / sidebar / list / paragraph))* closingDelim:(lf* @(example_delimiter_line / eof))
  {
    const delimiter = exitBlock(context)
    if (!closingDelim) console.log('unclosed example block')
    return { name: 'example', type: 'block', form: 'delimited', delimiter, blocks, location: toSourceLocation(getLocation()) }
  }

sidebar_delimiter_line = @$('****' [*]*) eol

sidebar = (openingDelim:sidebar_delimiter_line &{ return enterBlock(context, openingDelim) }) blocks:(lf* @(heading / example / sidebar / list / paragraph))* closingDelim:(lf* @(sidebar_delimiter_line / eof))
  {
    const delimiter = exitBlock(context)
    if (!closingDelim) console.log('unclosed sidebar block')
    return { name: 'sidebar', type: 'block', form: 'delimited', delimiter, blocks, location: toSourceLocation(getLocation()) }
  }

// NOTE: use items:(@list_item @(lf* @list_item)*) to avoid having to check lf and list_marker on first item
list = &(marker:list_start &{ return isNewList(context, marker) }) items:(lf* @list_item)+
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
    const variant = marker[0] === '*' ? 'unordered' : 'ordered'
    return { name: 'list', type: 'block', variant, marker, items: items, location: toSourceLocation(getLocation()) }
  }

list_start = @list_marker !(space / lf)

list_marker = @($'*'+ / $'.'+ / '-' / $([0-9]+ '.')) space

list_item_principal = first:line wrapped:(!(block_attribute_line / list_continuation_line / list_start / any_compound_block_delimiter_line) @line)*
  {
    return wrapped.length ? first + '\n' + wrapped.join('\n') : first
  }

list_continuation_line = '+' eol

// TODO transform list_item_principal before blocks (perform in list_item_principal rule)
// TODO process block attribute lines above attached blocks
list_item = marker:list_marker &{ return isCurrentList(context, marker) } principal:list_item_principal blocks:(list_continuation_line @(listing / example) / lf* @list)*
  {
    const location_ = getLocation()
    const principalInlines = parseInline(principal, { attributes: documentAttributes, locations: createLocationsForInlines(location_, marker.length + 2) })
    return { name: 'listItem', type: 'block', marker, principal: principalInlines, blocks, location: toSourceLocation(location_) }
  }

image = 'image::' !space target:$[^\n\[]+ '[' attrlist:attrlist ']' eol
  {
    return { name: 'image', type: 'block', form: 'macro', target, attributes: attrlist ? attrlist.split(',') : [], location: toSourceLocation(getLocation()) }
  }

any_compound_block_delimiter_line = example_delimiter_line / sidebar_delimiter_line

grab_offset = ''
  {
    return peg$currPos
  }

line = @$[^\n]+ eol

line_or_empty_line = line / lf @''

indented_line = @$(space [^\n]+) eol

attrlist = !space @$(!(lf / space? ']' eol) .)*

space = ' '

lf = '\n'

eof = !.

eol = '\n' / !.
