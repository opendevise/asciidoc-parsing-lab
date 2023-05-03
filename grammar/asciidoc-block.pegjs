{{
const { createContext, enterBlock, exitBlock, isBlockEnd, isCurrentList, isNestedSection, isNewList, toInlines } = require('#block-helpers')
}}
{
const { attributes: documentAttributes = {} } = options
const context = createContext()
const parseInline = (options.inlineParser ?? require('#block-default-inline-parser')).parse

function blockLocation (range_) {
  let eof
  const { start, end } = range_ === true ? (eof = true) && range() : range_ || range()
  const { line: startLine, column: startCol } = peg$computePosDetails(start)
  const startDetails = { line: startLine, col: startCol }
  if (end === start) return [startDetails, startDetails]
  if (eof) {
    const { line: endLine, column: endCol } = peg$computePosDetails(end)
    return [startDetails, { line: endLine, col: (endCol - 1) || 1 }]
  } else {
    const { line: endLine, column: endCol } = peg$computePosDetails(end - (end < input.length || (input[end - 1] ?? '\n') === '\n' ? 2 : 1))
    return [startDetails, { line: endLine, col: endCol }]
  }
}
}
document = header:header? body:body lf*
  {
    const location_ = blockLocation(true)
    if (header == null) return { name: 'document', type: 'block', blocks: body, location: location_ }
    const attributes = header.attributes
    delete header.attributes
    return { name: 'document', type: 'block', attributes, header, blocks: body, location: location_ }
  }

attribute_entry = ':' name:attribute_name ':' value:attribute_value eol
  {
    return [name, value]
  }

// TODO permit non-ASCII letters in attribute name
attribute_name = !'-' @$[a-zA-Z0-9_-]+

attribute_value = (' ' @$[^\n]+ / '')

block_attribute_line = '[' @attrlist ']' eol

// TODO allow doctitle to be optional
header = attribute_entries_above:attribute_entry* doctitle:doctitle attribute_entries_below:attribute_entry* &eol
  {
    const attributes = {}
    for (const attribute_entries of [attribute_entries_above, attribute_entries_below]) {
      if (!attribute_entries.length) continue
      for (const [name, val] of attribute_entries) {
        if (!(name in documentAttributes)) attributes[name] = val
      }
    }
    const titleStartLine = location().start.line + attribute_entries_above.length
    return { title: { inlines: parseInline(doctitle, { startLine: titleStartLine, startCol: 3 }) }, attributes }
  }

// TODO be more strict about doctitle chars; namely require a non-space
doctitle = '= ' @line

body = block*

// blocks = // does not include check for section; paragraph can just be paragraph
// blocks_in_section_body = // includes check for section; paragraph has to be paragraph_not_heading

block = lf* metadataStart:grab_offset metadata:(attrlists:(@block_attribute_line lf*)* metadataEnd:grab_offset {
    // TODO move this logic to a helper function or grammar rule
    if (!attrlists.length) return undefined
    while (input[metadataEnd - 1] === '\n' && input[metadataEnd - 2] === '\n') metadataEnd--
    const location_ = blockLocation({ start: metadataStart, end: metadataEnd })
    const attributes = {}
    const options = []
    for (const attrlist of attrlists) {
      if (!attrlist) return next
      // FIXME this is a quick hack
      let positionalIndex = 0
      attrlist.split(',').forEach((it) => {
        let equalsIdx = it.indexOf('=')
        if (~equalsIdx) {
          const name = it.slice(0, equalsIdx)
          const value = it.slice(equalsIdx + 1)
          if (name === 'opts' || name === 'options') {
            for (const opt of value.split(',')) {
              if (!~options.indexOf(opt)) options.push(opt)
            }
          } else if (name === 'role' && 'role' in attributes) {
            if (value) attributes.role += ' ' + value
          } else {
            attributes[name] = value
          }
        } else {
          attributes[++positionalIndex] = it
        }
      })
    }
    // NOTE once we get into parsing attribute values, this will change to an overlay object
    return { attributes, options, location: location_ }
  }) block:(section_or_discrete_heading / listing / example / sidebar / list / image / paragraph)
  {
    return metadata ? Object.assign(block, { metadata }) : block
  }

section_or_discrete_heading = heading:heading blocks:(&{ return options.currentAttributes?.['1'] === 'discrete' } / &{ return isNestedSection(context, heading) } @block*)
  {
    if (!blocks) return heading
    context.sectionStack.pop()
    return Object.assign(heading, { name: 'section', blocks, location: blockLocation() })
  }

paragraph = !heading lines:(!(block_attribute_line / any_compound_block_delimiter_line) @line)+
  {
    const location_ = blockLocation()
    return { name: 'paragraph', type: 'block', inlines: parseInline(lines.join('\n'), { startLine: location_[0].line }), location: location_ }
  }

heading = marker:'='+ ' ' title:line
  {
    const location_ = blockLocation()
    // Q should we store marker instead of or in addition to level?
    return { name: 'heading', type: 'block', title: { inlines: parseInline(title, { startLine: location_[0].line, startCol: marker.length + 2 }) }, level: marker.length - 1, location: location_ }
  }

listing_delimiter = @$('----' [-]*) eol

// FIXME pull lines out as separate rule to track location without having to hack location of parent
listing = (openingDelim:listing_delimiter { enterBlock(context, openingDelim) }) lines:(!(delim:listing_delimiter &{ return isBlockEnd(context, delim) }) @line)* closingDelim:(@listing_delimiter / eof)
  {
    const delimiter = exitBlock(context)
    if (closingDelim === undefined || (closingDelim !== delimiter && lines.push(closingDelim))) {
      console.log('unclosed listing block')
    }
    // Q should start location include all block attribute lines? or should that information be on the attributedefs?
    const location_ = blockLocation()
    // FIXME could this be captured from rule instead of computed?
    let inlines = []
    if (lines.length) {
      const contentsLocation = [{ line: location_[0].line + 1, col: 1 }, { line: location_[1].line - 1, col: lines[lines.length - 1].length }]
      inlines = toInlines('text', lines.join('\n'), contentsLocation)
    }
    return { name: 'listing', type: 'block', form: 'delimited', delimiter, inlines, location: location_ }
  }

example_delimiter_line = @$('====' [=]*) eol

example = (openingDelim:example_delimiter_line &{ return enterBlock(context, openingDelim) }) blocks:(lf* @(example / sidebar / list / paragraph))* closingDelim:(lf* @(example_delimiter_line / eof))
  {
    const delimiter = exitBlock(context)
    if (closingDelim === undefined) console.log('unclosed example block')
    return { name: 'example', type: 'block', form: 'delimited', delimiter, blocks, location: blockLocation() }
  }

sidebar_delimiter_line = @$('****' [*]*) eol

sidebar = (openingDelim:sidebar_delimiter_line &{ return enterBlock(context, openingDelim) }) blocks:(lf* @(example / sidebar / list / paragraph))* closingDelim:(lf* @(sidebar_delimiter_line / eof))
  {
    const delimiter = exitBlock(context)
    if (closingDelim === undefined) console.log('unclosed sidebar block')
    return { name: 'sidebar', type: 'block', form: 'delimited', delimiter, blocks, location: blockLocation() }
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
    return { name: 'list', type: 'block', variant, marker, items: items, location: blockLocation() }
  }

list_start = @list_marker ![ \n]

list_marker = @($'*'+ / $'.'+ / '-' / $([0-9]+ '.')) ' '

list_item_principal = first:line wrapped:(!(block_attribute_line / list_continuation_line / list_start / any_compound_block_delimiter_line) @line)*
  {
    return wrapped.length ? first + '\n' + wrapped.join('\n') : first
  }

list_continuation_line = '+' eol

// TODO transform list_item_principal before blocks (perform in list_item_principal rule)
// TODO process block attribute lines above attached blocks
list_item = marker:list_marker &{ return isCurrentList(context, marker) } principal:list_item_principal blocks:(list_continuation_line @(listing / example) / lf* @list)*
  {
    const location_ = blockLocation()
    return { name: 'listItem', type: 'block', marker, principal: { inlines: parseInline(principal, { startLine: location_[0].line, startCol: marker.length + 2 }) }, blocks, location: location_ }
  }

image = 'image::' !space target:$[^\n\[]+ '[' attrlist:attrlist ']' eol
  {
    return { name: 'image', type: 'block', form: 'macro', target, attributes: attrlist ? attrlist.split(',') : [], location: blockLocation() }
  }

any_compound_block_delimiter_line = example_delimiter_line / sidebar_delimiter_line

grab_offset = ''
  {
    return offset()
  }

line = @$[^\n]+ eol

attrlist = $[^\n\]]*

space = ' '

lf = '\n'

eof = !.

eol = '\n' / !.
