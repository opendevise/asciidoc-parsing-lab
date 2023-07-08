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
  let eof, text
  let { start, end = start + (text = range_.text || '').length } = range_ === true ? (eof = true) && range() : range_ ?? range()
  const { line: startLine, column: startCol } = peg$computePosDetails(start)
  const startDetails = { line: startLine, col: end || text != null ? (input[start] === '\n' ? 0 : startCol) : 0 }
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

function parseBlockMetadata (attrlists, { start: startOffset, end: endOffset }) {
  const cacheKey = endOffset
  if (cacheKey in metadataCache) return metadataCache[cacheKey]
  while (input[endOffset - 1] === '\n' && input[endOffset - 2] === '\n') endOffset--
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
  const sourceLocation = toSourceLocation(getLocation({ start: startOffset, end: endOffset }))
  return (metadataCache[cacheKey] = { attributes, options: undefined, roles: undefined, location: sourceLocation })
}

function processBlockMetadata (cacheKey = offset(), posattrs) {
  const metadata = metadataCache[cacheKey]
  if (!metadata || metadata.options) return metadata
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
  const promote = {}
  if ('id' in attributes) promote.id = attributes.id
  attributes.opts ? (attributes.opts = (metadata.options = [...attributes.opts]).join(',')) : (metadata.options = [])
  attributes.role ? (attributes.role = (metadata.roles = [...attributes.role]).join(' ')) : (metadata.roles = [])
  for (const name of names) {
    const valueObject = attributes[name]
    if (valueObject.constructor !== Function) continue
    if (contentAttributeNames.includes(name)) {
      ;({ value: attributes[name], inlines: promote[name] } = valueObject(true))
    } else {
      attributes[name] = valueObject()
    }
  }
  return Object.keys(promote).length ? Object.assign(metadata, { promote }) : metadata
}

function applyBlockMetadata (block, metadata) {
  if (!metadata) return block
  if (metadata.promote) {
    Object.assign(block, metadata.promote)
    delete metadata.promote
  }
  return Object.assign(block, { metadata })
}
}
// TODO if surrounding lf are not part of document, group inner two rules as a new rule
document = lf* header:header? blocks:body unparsed:.*
  {
    const node = { name: 'document', type: 'block' }
    if (header) {
      node.attributes = header.attributes
      delete header.attributes
      node.header = header
    }
    if (unparsed.length && options.showWarnings) {
      console.warn(`unparsed content found at end of document:\n${unparsed.join('').trimEnd()}`)
    }
    return Object.assign(node, { blocks, location: toSourceLocation(getLocation(true)) })
  }

attribute_entry = ':' negatedPrefix:'!'? name:attribute_name negatedSuffix:'!'? ':' value:attribute_value? eol
  {
    return [name, negatedPrefix || negatedSuffix ? null : value || '']
  }

// TODO permit non-ASCII letters in attribute name
attribute_name = $([a-zA-Z0-9_] [a-zA-Z0-9_-]*)

attribute_value = space @$(!lf .)+

header = attributeEntriesAbove:attribute_entry* doctitleAndAttributeEntries:(doctitle author_info_line? attributeEntriesBelow:attribute_entry*)? &{ return doctitleAndAttributeEntries || attributeEntriesAbove.length }
  {
    const attributes = {}
    const header = {}
    const sourceLocation = toSourceLocation(getLocation())
    if (attributeEntriesAbove.length) {
      for (const [name, val] of attributeEntriesAbove) {
        if (name in documentAttributes && !(name in attributes)) continue
        if (val == null) {
          attributes[name] = val
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
          if (val == null) {
            attributes[name] = null
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
author_info_item = names:author_name|1..3, space| address:(' <' @$(!('>' / lf) .)+ '>')?
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

body = @section_block* remainder

compound_block_body = @block* remainder

remainder = lf* ((block_attribute_line / block_title_line) lf*)*

block_metadata = attrlists:(@(block_attribute_line / block_title_line) lf*)*
  {
    return attrlists.length ? parseBlockMetadata(attrlists, range()) : undefined
  }

block_attribute_line = @'[' @offset @attrlist ']' eol

// NOTE don't match line that starts with '. ' or '.. ' (which could be a list marker) or '...' (which could be a literal block delimiter or list marker)
block_title_line = @'.' @offset @$('.'? (!(lf / ' ' / '.') .) (!lf .)*) eol

// NOTE !heading is checked first since section_or_discrete_heading rule will fail at ancestor section, but should not then match a different rule
section_block = lf* block_metadata @(!heading @(listing / literal / example / sidebar / list / dlist / indented / image / paragraph) / section_or_discrete_heading)

block = lf* block_metadata @(discrete_heading / listing / literal / example / sidebar / list / dlist / indented / image / paragraph)

section_or_discrete_heading = startOffset:offset headingRecord:heading metadataAndBlocks:(&{ return metadataCache[startOffset]?.attributes.style === 'discrete' } { return [processBlockMetadata(startOffset)] } / (&{ return isNestedSection(context, headingRecord[0].length - 1) } { return processBlockMetadata(startOffset) }) section_block*)
  {
    const [marker, titleOffset, title] = headingRecord
    const [metadata, blocks] = metadataAndBlocks
    const location_ = getLocation()
    const inlines = parseInline(title, { attributes: documentAttributes, locations: createLocationsForInlines(location_, titleOffset - startOffset) })
    // Q: store marker instead of or in addition to level?
    const node = { name: 'heading', type: 'block', title: inlines, level: marker.length - 1, location: toSourceLocation(location_) }
    if (blocks) {
      exitSection(context)
      Object.assign(node, { name: 'section', blocks })
    }
    return applyBlockMetadata(node, metadata)
  }

discrete_heading = headingRecord:heading
  {
    const [marker, titleOffset, title] = headingRecord
    const location_ = getLocation()
    const metadata = processBlockMetadata()
    const inlines = parseInline(title, { attributes: documentAttributes, locations: createLocationsForInlines(location_, titleOffset - offset()) })
    // Q: store marker instead of or in addition to level?
    const node = { name: 'heading', type: 'block', title: inlines, level: marker.length - 1, location: toSourceLocation(location_) }
    return applyBlockMetadata(node, metadata)
  }

heading = @$('=' '='*) space space* @offset @line

// TODO in order to enable list matching shorthand, must ensure this rule is only called when all other syntax has been exhausted
//paragraph = lines:line|1.., !(block_attribute_line / any_block_delimiter_line)|
paragraph = lines:(!(block_attribute_line / any_block_delimiter_line) @line)+
  {
    const location_ = getLocation()
    const metadata = processBlockMetadata()
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
    const location_ = getLocation()
    const metadata = processBlockMetadata()
    const indents = []
    for (const line of lines) indents.push(line.length - line.trimStart().length)
    const outdent = Math.min.apply(null, indents)
    const contents = lines.reduce((accum, l) => accum + '\n' + l.slice(outdent), '').slice(1)
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

listing_contents = (!(delim:listing_delimiter_line &{ return isBlockEnd(context, delim) }) line_or_empty_line)*
  {
    let { start, end } = range()
    if (end === start) return
    const value = input.substring(start, (end === input.length ? end : --end) + (input[end] === '\n' ? 0 : 1))
    const location_ = getLocation({ start, end: value ? end : start })
    if (value && value[value.length - 1] === '\n') {
      location_[1].line++
      location_[1].col = 0
    }
    return [value || '\n', location_]
  }

listing = (openingDelim:listing_delimiter_line { enterBlock(context, openingDelim) }) contents:listing_contents closingDelim:(@listing_delimiter_line / eof)
  {
    const delimiter = exitBlock(context)
    const metadata = processBlockMetadata()
    const name = metadata?.attributes.style === 'literal' ? 'literal' : 'listing'
    if (!closingDelim && options.showWarnings) console.warn(`unclosed ${name} block`)
    const inlines = contents ? toInlines('text', contents[0], toSourceLocation(contents[1])) : []
    const node = { name, type: 'block', form: 'delimited', delimiter, inlines, location: toSourceLocation(getLocation(closingDelim ? undefined : true)) }
    return applyBlockMetadata(node, metadata)
  }

literal_delimiter_line = @$('.' '.'|3..|) eol

literal_contents = (!(delim:literal_delimiter_line &{ return isBlockEnd(context, delim) }) line_or_empty_line)*
  {
    let { start, end } = range()
    if (end === start) return
    const value = input.substring(start, (end === input.length ? end : --end) + (input[end] === '\n' ? 0 : 1))
    const location_ = getLocation({ start, end: value ? end : start })
    if (value && value[value.length - 1] === '\n') {
      location_[1].line++
      location_[1].col = 0
    }
    return [value || '\n', location_]
  }

literal = (openingDelim:literal_delimiter_line { enterBlock(context, openingDelim) }) contents:literal_contents closingDelim:(@literal_delimiter_line / eof)
  {
    const delimiter = exitBlock(context)
    const metadata = processBlockMetadata()
    const name = metadata?.attributes.style === 'listing' ? 'listing' : 'literal'
    if (!closingDelim && options.showWarnings) console.warn(`unclosed ${name} block`)
    const inlines = contents ? toInlines('text', contents[0], toSourceLocation(contents[1])) : []
    const node = { name, type: 'block', form: 'delimited', delimiter, inlines, location: toSourceLocation(getLocation(closingDelim ? undefined : true)) }
    return applyBlockMetadata(node, metadata)
  }

example_delimiter_line = @$('=' '='|3..|) eol

example = metadata:(startOffset:offset openingDelim:example_delimiter_line &{ return enterBlock(context, openingDelim) } { return processBlockMetadata(startOffset) }) blocks:compound_block_body closingDelim:(lf* @(example_delimiter_line / eof))
  {
    const delimiter = exitBlock(context)
    let name = 'example'
    let style, admonitionVariant
    if ((style = metadata?.attributes.style) && (admonitionVariant = ADMONITION_STYLES[style])) name = 'admonition'
    if (!closingDelim && options.showWarnings) console.warn(`unclosed ${name} block`)
    const node = { name, type: 'block', form: 'delimited', delimiter, variant: admonitionVariant, blocks, location: toSourceLocation(getLocation(closingDelim ? undefined : true)) }
    if (!admonitionVariant) delete node.variant
    return applyBlockMetadata(node, metadata)
  }

sidebar_delimiter_line = @$('*' '*'|3..|) eol

sidebar = metadata:(startOffset:offset openingDelim:sidebar_delimiter_line &{ return enterBlock(context, openingDelim) } { return processBlockMetadata(startOffset) }) blocks:compound_block_body closingDelim:(lf* @(sidebar_delimiter_line / eof))
  {
    const delimiter = exitBlock(context)
    if (!closingDelim && options.showWarnings) console.warn('unclosed sidebar block')
    const node = { name: 'sidebar', type: 'block', form: 'delimited', delimiter, blocks, location: toSourceLocation(getLocation(closingDelim ? undefined : true)) }
    return applyBlockMetadata(node, metadata)
  }

list = metadata:(&(marker:list_marker &{ return isNewList(context, marker) }) { return processBlockMetadata() }) items:list_item|1.., lf*|
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
    // NOTE set location end of list to location end of last list item; prevents overrun caused by looking for ancestor list continuation
    const sourceLocation = toSourceLocation(getLocation({ start: offset() }))
    sourceLocation[1] = items[items.length - 1].location[1]
    return applyBlockMetadata({ name: 'list', type: 'block', variant, marker, items, location: sourceLocation }, metadata)
  }

list_marker = space* @$('*' '*'* / '.' '.'* / '-' / [0-9] [0-9]* '.') space space* !eol

list_item_principal = lines:line|1.., !list_item_principal_interrupting_line|
  {
    const location_ = getLocation()
    return parseInline(lines.join('\n'), { attributes: documentAttributes, locations: createLocationsForInlines(location_, location_[0].col - 1) })
  }

list_item_principal_interrupting_line = block_attribute_line / list_continuation / list_marker / dlist_term / any_block_delimiter_line

list_continuation = '+' eol

// Q should block match after list continuation end with '?', or should last alternative be '!.'?
// Q should @block? be changed to @(block / block_metadata {}) or should we let the parent handle the orphaned metadata lines?
list_item = marker:list_marker &{ return isCurrentList(context, marker) } principal:list_item_principal blocks:(list_continuation @block? / (lf lf* / block_metadata) @(list / dlist / &space !(list_marker / dlist_term) @indented))* trailer:lf?
  {
    if (blocks.length && blocks[blocks.length - 1] == null) blocks.pop()
    let sourceLocation
    if (blocks.length) {
      sourceLocation = toSourceLocation(getLocation({ start: offset() }))
      sourceLocation[1] = blocks[blocks.length - 1].location[1]
    } else {
      const range_ = range()
      if (trailer) range_.end--
      sourceLocation = toSourceLocation(getLocation(range_))
    }
    // or use a more brute-force approach...
    //const range_ = range()
    //if (trailer || blocks.length) {
    //  while (input[range_.end - 1] === '\n') range_.end--
    //}
    //const sourceLocation = toSourceLocation(getLocation(range_))
    return { name: 'listItem', type: 'block', marker, principal, blocks, location: sourceLocation }
  }

dlist = metadata:(&(termRecord:dlist_term &{ return isNewList(context, termRecord[2]) }) { return processBlockMetadata() }) items:dlist_item|1.., lf*|
  {
    const marker = exitList(context)
    return applyBlockMetadata({ name: 'dlist', type: 'block', marker, items, location: toSourceLocation(getLocation()) }, metadata)
  }

dlist_term = space* @offset @$(!lf (!':' . / ':' (!':' / ':'|1..| !(space / eol))))+ @$(':' ':'|1..|) &(space / eol)

dlist_term_for_current_item = termRecord:dlist_term &{ return isCurrentList(context, termRecord[2]) }
  {
    return { inlines: parseInline(termRecord[1].trimEnd(), { attributes: documentAttributes, locations: createLocationsForInlines(getLocation(), termRecord[0] - offset()) }), marker: termRecord[2] }
  }

dlist_item = term:dlist_term_for_current_item moreTerms:(lf lf* @dlist_term_for_current_item)* principal:(space space* @(&eol / list_item_principal) / @(lf lf* (!(space / list_item_principal_interrupting_line) / space !(list_marker / dlist_term) space*) @list_item_principal) / &eol) blocks:(list_continuation @block? / (lf lf* / block_metadata) @(list / dlist / &space !(list_marker / dlist_term) @indented))* trailer:lf?
  {
    if (blocks.length && blocks[blocks.length - 1] == null) blocks.pop()
    let sourceLocation
    if (blocks.length) {
      sourceLocation = toSourceLocation(getLocation({ start: offset() }))
      sourceLocation[1] = blocks[blocks.length - 1].location[1]
    } else {
      const range_ = range()
      if (trailer) range_.end--
      sourceLocation = toSourceLocation(getLocation(range_))
    }
    // ...or see list_item rule for more brute-force approach
    const marker = term.marker
    const terms = moreTerms.length ? [term.inlines, ...moreTerms.map(({ inlines }) => inlines)] : [term.inlines]
    const node = { name: 'dlistItem', type: 'block', marker, terms, principal, blocks, location: sourceLocation }
    if (!principal) delete node.principal
    return node
  }

image = 'image::' !space target:$(!(lf / '[') .)+ '[' attrlistOffset:offset attrlist:attrlist ']' eol
  {
    if (attrlist) parseAttrlist(attrlist, { attributes: documentAttributes, initial: (metadataCache[offset()] ??= { attributes: {} }).attributes, inlineParser: { parse: parseInline }, locations: { 1: toSourceLocation(getLocation({ start: attrlistOffset, text: attrlist }))[0] } })
    const metadata = processBlockMetadata(undefined, ['alt', 'width', 'height'])
    target = inlinePreprocessor(target, { attributes: documentAttributes, mode: 'attributes', sourceMapping: false }).input
    return applyBlockMetadata({ name: 'image', type: 'block', form: 'macro', target, location: toSourceLocation(getLocation()) }, metadata)
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
