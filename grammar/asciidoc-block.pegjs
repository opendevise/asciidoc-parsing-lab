{{
const { createContext, enterBlock, exitBlock, isBlockEnd, isCurrentList, isNestedSection, isNewList, toInlines } = require('#block-helpers')
}}
{
const context = createContext()
// TODO parseInline should short-circuit if no markup characters are detected
const parseInline = (options.inlineParser ?? require('#block-default-inline-parser')).parse

function blockLocation (eof) {
  const { start, end, startDetails = peg$computePosDetails(start) } = range()
  if (end === start) return { start: startDetails, end: startDetails }
  if (eof) {
    const { line, column } = peg$computePosDetails(end)
    return { start: startDetails, end: { line, column: (column - 1) || 1 } }
  }
  const endDetails = peg$computePosDetails(end - (end < input.length || (input[end - 1] ?? '\n') === '\n' ? 2 : 1))
  return { start: startDetails, end: endDetails }
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

// TODO be more strict/specific about attribute name
attribute_name = $[a-z]+

attribute_value = (' ' @$[^\n]+ / '')

block_attribute_line = '[' @attrlist ']' eol

// TODO clean up handling of attribute entries above/below
// TODO allow doctitle to be optional
header = attribute_entries_above:attribute_entry* doctitle:doctitle attribute_entries_below:attribute_entry* &(lf / eof)
  {
    const attributes = attribute_entries_above.length
      ? attribute_entries_above.reduce((accum, [name, val]) => Object.assign(accum, { [name]: val }), {})
      : {}
    attribute_entries_below.length &&
      attribute_entries_below.reduce((accum, [name, val]) => Object.assign(accum, { [name]: val }), attributes)
    const titleStartLine = location().start.line + attribute_entries_above.length
    return { title: { inlines: parseInline(doctitle, { startLine: titleStartLine, startColumn: 3 }) }, attributes }
  }

// TODO be more strict about doctitle chars; namely require a non-space
doctitle = '= ' @line

body = block*

// blocks = // does not include check for section; paragraph can just be paragraph
// blocks_in_section_body = // includes check for section; paragraph has to be paragraph_not_heading

block = lf* attributes:(attrlists:(@block_attribute_line lf*)* {
    return (options.currentAttributes = attrlists.reduce((accum, attrlist) => {
      if (attrlist) {
        accum ??= {}
        // FIXME this is a quick hack
        let positionalIndex = 0
        attrlist.split(',').forEach((it) => {
          let equalsIdx = it.indexOf('=')
          if (~equalsIdx) {
            accum[it.slice(0, equalsIdx)] = it.slice(equalsIdx + 1)
          } else {
            accum[++positionalIndex] = it
          }
        })
      }
      return accum
    }, undefined))
  }) block:(section_or_discrete_heading / listing / example / sidebar / list / image / paragraph)
  {
    return attributes ? Object.assign(block, { attributes }) : block
  }

section_or_discrete_heading = heading:heading blocks:(&{ return options.currentAttributes?.['1'] === 'discrete' } / &{ return isNestedSection(context, heading) } @block*)
  {
    if (!blocks) return heading
    context.sectionStack.pop()
    return Object.assign(heading, { name: 'section', blocks, location: blockLocation() })
  }

paragraph = !heading lines:(!(block_attribute_line / delim:any_compound_block_delimiter_line &{ return isBlockEnd(context, delim) }) @line)+
  {
    const location_ = blockLocation()
    return { name: 'paragraph', type: 'block', inlines: parseInline(lines.join('\n'), { startLine: location_.start.line }), location: location_ }
  }

heading = marker:'='+ ' ' title:line
  {
    const location_ = blockLocation()
    // Q should we store marker instead of or in addition to level?
    return { name: 'heading', type: 'block', title: { inlines: parseInline(title, { startLine: location_.start.line, startColumn: marker.length + 2}) }, level: marker.length - 1, location: location_ }
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
      const contentsLocation = { start: { line: location_.start.line + 1, column: 1 }, end: { line: location_.end.line - 1, column: lines[lines.length - 1].length } }
      inlines = toInlines('text', lines.join('\n'), contentsLocation)
    }
    return { name: 'listing', type: 'block', form: 'delimited', delimiter, inlines, location: location_ }
  }

example_delimiter_line = @$('====' [=]*) eol

example = (openingDelim:example_delimiter_line &{ return enterBlock(context, openingDelim) }) blocks:(@example / @sidebar / @list / paragraph)* closingDelim:(@example_delimiter_line / eof)
  {
    const delimiter = exitBlock(context)
    if (closingDelim === undefined) console.log('unclosed example block')
    return { name: 'example', type: 'block', form: 'delimited', delimiter, blocks, location: blockLocation() }
  }

sidebar_delimiter_line = @$('****' [*]*) eol

sidebar = (openingDelim:sidebar_delimiter_line &{ return enterBlock(context, openingDelim) }) blocks:(@example / @sidebar / paragraph)* closingDelim:(@sidebar_delimiter_line / eof)
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

list_marker = @($[*]+ / $[.]+ / '-' / $([0-9]+ '.')) ' '

list_item_principal = text:$(line (!(block_attribute_line / list_continuation_line / list_start / any_compound_block_delimiter_line) @line)*)
  {
    // FIXME is there a way to avoid this check using the grammar rules?
    return text[text.length - 1] === '\n' ? text.slice(0, -1) : text
  }

list_continuation_line = '+' eol

// TODO transform list_item_principal before blocks (perform in list_item_principal rule)
// TODO process block attribute lines above attached blocks
list_item = marker:list_marker &{ return isCurrentList(context, marker) } principal:list_item_principal blocks:(list_continuation_line @(listing / example) / lf* @list)*
  {
    const location_ = blockLocation()
    return { name: 'listItem', type: 'block', marker, principal: { inlines: parseInline(principal, { startLine: location_.start.line, startColumn: marker.length + 2 }) }, blocks, location: location_ }
  }

image = 'image::' !space target:$[^\n\[]+ '[' attrlist:attrlist ']' eol
  {
    return { name: 'image', type: 'block', form: 'macro', target, attributes: attrlist ? attrlist.split(',') : [], location: blockLocation() }
  }

any_compound_block_delimiter_line = example_delimiter_line / sidebar_delimiter_line

line = @$[^\n]+ eol

attrlist = $[^\n\]]*

space = ' '

lf = '\n'

eof = !.

eol = '\n' / eof
