/* eslint-env mocha */
'use strict'

const { expect } = require('#test-harness')
const { parse } = require('#attrlist-parser')
const inlineParser = require('#inline-parser')

describe('attrlist (unported)', () => {
  const parseWithShorthands = (source, opts = {}) => {
    return parse(source, Object.assign(opts, { startRule: 'block_attrlist_with_shorthands' }))
  }

  describe('positional attributes', () => {
    it('should parse single positional attribute', () => {
      const expected = { $1: 'value' }
      expect(parse('value')).to.eql(expected)
    })

    it('should parse multiple positional attributes', () => {
      const expected = { $1: 'a', $2: 'b' }
      expect(parse('a,b')).to.eql(expected)
    })

    it('should not set positional attribute if value is empty', () => {
      const expected = { $3: 'c' }
      expect(parse(', ,c')).to.eql(expected)
    })

    it('should allow spaces around delimiter separating positional attributes', () => {
      const expected = { $1: 'a', $2: 'b', $3: 'c' }
      expect(parse('a, b ,c')).to.eql(expected)
    })

    it('should number positional attributes intermingled with named attributes', () => {
      const expected = { $1: 'a', $2: 'b', name: 'value' }
      expect(parse('a,name=value,b')).to.eql(expected)
    })
  })

  describe('shorthand attributes', () => {
    it('should assign first positional attribute as style if it contains valid characters', () => {
      const expected = { $1: 'normal', $2: 'b', style: 'normal' }
      expect(parseWithShorthands('normal,b')).to.eql(expected)
    })

    it('should parse shorthand id in first positional attribute', () => {
      const shorthand = '#idname'
      const expected = { $1: shorthand, id: 'idname' }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should parse shorthand roles in first positional attribute', () => {
      const shorthand = '.role1.role2'
      const expected = { $1: shorthand, role: new Set(['role1', 'role2']) }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should parse shorthand options in first positional attribute', () => {
      const shorthand = '%opt1%opt2'
      const expected = { $1: shorthand, opts: new Set(['opt1', 'opt2']) }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should parse block anchor in first positional attribute', () => {
      const shorthand = '[idname]'
      const expected = { $1: shorthand, id: 'idname' }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should parse block anchor with reftext in first positional attribute', () => {
      const shorthand = '[idname,reference text]'
      const expected = {
        $1: shorthand,
        id: 'idname',
        reftext: {
          value: 'reference text',
          inlines: [{
            name: 'text',
            type: 'string',
            value: 'reference text',
            location: [{ line: 1, col: 10 }, { line: 1, col: 23 }],
          }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      expect(parseWithShorthands(shorthand, { locations, inlineParser })).to.eql(expected)
    })

    it('should process escaped closing square bracket in reftext of block anchor', () => {
      const shorthand = '[idname,reference [text\\]]'
      const expected = {
        $1: shorthand,
        id: 'idname',
        reftext: {
          value: 'reference [text]',
          inlines: [{
            name: 'text',
            type: 'string',
            value: 'reference [text]',
            location: [{ line: 1, col: 10 }, { line: 1, col: 26 }],
          }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      expect(parseWithShorthands(shorthand, { locations, inlineParser })).to.eql(expected)
    })

    it('should set reftext to empty if value of reftext in block anchor is empty', () => {
      const shorthand = '[idname,]'
      const expected = {
        $1: shorthand,
        id: 'idname',
        reftext: {
          value: '',
          inlines: [],
        },
      }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should not recognize shorthand if contains space', () => {
      const shorthand = '.foo bar'
      const expected = { $1: shorthand }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should not set style if it contains a space', () => {
      const shorthand = 'not a style'
      const expected = { $1: shorthand }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should not recognize shorthands if style contains a space', () => {
      const shorthand = 'not a style.unparsed'
      const expected = { $1: shorthand }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should not recognize shorthand if value is empty', () => {
      const shorthand = '.%opt1'
      const expected = { $1: shorthand }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should parse all shorthands in first positional attribute', () => {
      const shorthand = '#idname.role1%opt1.role2%opt2'
      const expected = {
        $1: shorthand,
        id: 'idname',
        role: new Set(['role1', 'role2']),
        opts: new Set(['opt1', 'opt2']),
      }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should parse all shorthands in first positional attribute followed by other attributes', () => {
      const shorthand = '#idname.role1%opt1.role2%opt2,indent=0'
      const expected = {
        $1: shorthand.split(',')[0],
        id: 'idname',
        role: new Set(['role1', 'role2']),
        opts: new Set(['opt1', 'opt2']),
        indent: '0',
      }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should parse shorthands following block anchor in first positional attribute', () => {
      const shorthand = '[idname,reference text].role1%opt1.role2%opt2'
      const expected = {
        $1: shorthand,
        id: 'idname',
        reftext: {
          value: 'reference text',
          inlines: [{
            name: 'text',
            type: 'string',
            value: 'reference text',
            location: [{ line: 1, col: 10 }, { line: 1, col: 23 }],
          }],
        },
        role: new Set(['role1', 'role2']),
        opts: new Set(['opt1', 'opt2']),
      }
      const locations = { 1: { line: 1, col: 2 } }
      expect(parseWithShorthands(shorthand, { locations })).to.eql(expected)
    })

    it('should extract style from first positional attribute that contains shorthands', () => {
      const shorthand = 'sidebar#s1'
      const expected = { $1: shorthand, style: 'sidebar', id: 's1' }
      expect(parseWithShorthands(shorthand)).to.eql(expected)
    })

    it('should not parse shorthands or extract style in first positional attribute if not in first position', () => {
      const shorthand = 'sidebar#idname.role1%opt1.role2%opt2'
      const expected = {
        $1: shorthand,
        lang: 'fr',
      }
      expect(parseWithShorthands('lang=fr,' + shorthand)).to.eql(expected)
    })
  })

  describe('named attributes', () => {
    it('should parse named attribute with unquoted value', () => {
      const expected = { name: 'value' }
      expect(parse('name=value')).to.eql(expected)
    })

    it('should allow spaces around equals sign of named attribute', () => {
      const expected = { name: 'value' }
      expect(parse('name =  value')).to.eql(expected)
    })

    it('should allow value of named attribute to be empty', () => {
      const expected = { name: '' }
      expect(parse('name=')).to.eql(expected)
    })

    it('should allow double-quoted value of named attribute to be empty', () => {
      const expected = { name: '' }
      expect(parse('name=""')).to.eql(expected)
    })

    it('should allow single-quoted value of named attribute to be empty', () => {
      const expected = { name: '' }
      expect(parse('name=\'\'')).to.eql(expected)
    })

    it('should ignore trailing spaces after attribute value', () => {
      const expected = { name: '' }
      expect(parse('name=  ')).to.eql(expected)
    })

    it('should preserve spaces if attribute value is quoted', () => {
      const expected = { name: '  ' }
      expect(parse('name="  "')).to.eql(expected)
    })

    it('should allow value to be enclosed in double quotes', () => {
      const expected = { name: 'value' }
      expect(parse('name="value"')).to.eql(expected)
    })

    it('should not allow double-quoted value to be followed by a character other than space or comma', () => {
      const expected = { foo: 'bar', yin: '"yang"yang' }
      expect(parse('foo="bar",yin="yang"yang')).to.eql(expected)
    })

    it('should not allow single-quoted value to be followed by a character other than space or comma', () => {
      const expected = { foo: 'bar', yin: '\'yang\'yang' }
      expect(parse('foo=\'bar\',yin=\'yang\'yang')).to.eql(expected)
    })

    it('should allow value to be enclosed in single quotes', () => {
      const expected = { name: 'value' }
      expect(parse('name=\'value\'')).to.eql(expected)
    })

    it('should allow unquoted value to be escaped', () => {
      const expected = { name: '\\' }
      expect(parse('name=\\')).to.eql(expected)
    })

    it('should allow double-quoted value to be escaped', () => {
      const expected = { name: '\\' }
      expect(parse('name="\\\\"')).to.eql(expected)
    })

    it('should allow single-quoted value to be escaped', () => {
      const expected = { name: '\\' }
      expect(parse('name=\'\\\\\'')).to.eql(expected)
    })

    it('should allow double-quoted value to be double quote', () => {
      const expected = { name: '"' }
      // NOTE read as: name="\""
      expect(parse('name="\\""')).to.eql(expected)
    })

    it('should allow single-quoted value to be single quote', () => {
      const expected = { name: '\'' }
      // NOTE read as: name='\''
      expect(parse('name=\'\\\'\'')).to.eql(expected)
    })

    it('should allow quoted value to contain quote preceded by backslash', () => {
      const expected = { name: '\\"' }
      // NOTE read as: name="\\\""
      expect(parse('name="\\\\\\""')).to.eql(expected)
    })

    it('should allow multiple double quotes to be escaped in double-quoted value', () => {
      const expected = { name: '"text"' }
      // NOTE read as: name="\"text\""
      expect(parse('name="\\"text\\""')).to.eql(expected)
    })

    it('should allow multiple single quotes to be escaped in single-quoted value', () => {
      const expected = { name: '\'text\'' }
      // NOTE read as: name='\'text\''
      expect(parse('name=\'\\\'text\\\'\'')).to.eql(expected)
    })

    it('should allow single quote in double-quoted value', () => {
      const expected = { name: '\'' }
      expect(parse('name="\'"')).to.eql(expected)
    })

    it('should allow double quote in single-quoted value', () => {
      const expected = { name: '"' }
      expect(parse('name=\'"\'')).to.eql(expected)
    })

    it('should not process backslashes in quoted value that do not precede a like quote', () => {
      const expected = { name: '\\a\\\\b' }
      expect(parse('name="\\a\\\\b"')).to.eql(expected)
    })

    it('should treat unbalanced double quote as part of attribute value', () => {
      const expected = { name: '"value' }
      expect(parse('name="value')).to.eql(expected)
    })

    it('should treat unbalanced single quote as part of attribute value', () => {
      const expected = { name: '\'value' }
      expect(parse('name=\'value')).to.eql(expected)
    })

    it('should treat unbalanced double quote as part of attribute value if closing quote is escaped', () => {
      const expected = { name: '"value\\"' }
      expect(parse('name="value\\"')).to.eql(expected)
    })

    it('should treat unbalanced single quote as part of attribute value if closing quote is escaped', () => {
      const expected = { name: '\'value\\\'' }
      expect(parse('name=\'value\\\'')).to.eql(expected)
    })

    it('should allow use of space as attribute separator when value is double quoted', () => {
      const expected = { foo: 'bar', yin: 'yang' }
      expect(parse('foo="bar" yin="yang"')).to.eql(expected)
    })

    it('should allow use of space as attribute separator when value is single quoted', () => {
      const expected = { foo: 'bar', yin: 'yang' }
      expect(parse('foo=\'bar\' yin=\'yang\'')).to.eql(expected)
    })

    it('should normalize value of role and opts attributes', () => {
      const expected = { role: new Set(['incremental', 'key']), opts: new Set(['this', 'that', 'theother']) }
      expect(parse('role="  incremental   key  ",opts=" this, that theother "')).to.eql(expected)
    })
  })

  describe('content attributes', () => {
    it('should convert unquoted value of reserved content attribute to inline array', () => {
      const expectedLocation = [{ line: 1, col: 8 }, { line: 1, col: 14 }]
      const expected = {
        title: {
          value: 'titleme',
          inlines: [{ name: 'text', type: 'string', value: 'titleme', location: expectedLocation }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      expect(parse('title=titleme', { contentAttributeNames: ['title'], locations })).to.eql(expected)
    })

    it('should convert unquoted empty value of reserved content attribute to empty inline array', () => {
      const expected = { title: { value: '', inlines: [] } }
      expect(parse('title=', { contentAttributeNames: ['title'] })).to.eql(expected)
    })

    it('should convert single-quoted empty value of reserved content attribute to empty inline array', () => {
      const expected = { title: { value: '', inlines: [] } }
      expect(parse('title=\'\'', { contentAttributeNames: ['title'] })).to.eql(expected)
    })

    it('should convert double-quoted value of reserved content attribute to inline array', () => {
      const expectedLocation = [{ line: 1, col: 9 }, { line: 1, col: 15 }]
      const expected = {
        title: {
          value: 'titleme',
          inlines: [{ name: 'text', type: 'string', value: 'titleme', location: expectedLocation }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      expect(parse('title="titleme"', { contentAttributeNames: ['title'], locations })).to.eql(expected)
    })

    it('should parse double-quoted value of reserved content attribute to inline array', () => {
      const expected = {
        title: {
          value: '*titleme*',
          inlines: [{
            name: 'span',
            type: 'inline',
            variant: 'strong',
            form: 'constrained',
            inlines: [{
              name: 'text',
              type: 'string',
              value: 'titleme',
              location: [{ line: 1, col: 10 }, { line: 1, col: 16 }],
            }],
            location: [{ line: 1, col: 9 }, { line: 1, col: 17 }],
          }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      const parseOpts = { contentAttributeNames: ['title'], locations, inlineParser }
      expect(parse('title=\'*titleme*\'', parseOpts)).to.eql(expected)
    })

    it('should convert quoted value of reserved content attribute with escaped quote to inline array', () => {
      const expectedLocation = [{ line: 1, col: 9 }, { line: 1, col: 28 }]
      const expected = {
        title: {
          value: 'using " effectively',
          inlines: [{ name: 'text', type: 'string', value: 'using " effectively', location: expectedLocation }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      expect(parse('title="using \\" effectively"', { contentAttributeNames: ['title'], locations })).to.eql(expected)
    })

    it('should set start location for value that starts with escaped backslash to location of escape', () => {
      const expectedLocation = [{ line: 1, col: 11 }, { line: 1, col: 25 }]
      const expected = {
        reftext: {
          value: '\\\' is rs + sq',
          inlines: [{ name: 'text', type: 'string', value: '\\\' is rs + sq', location: expectedLocation }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      const parseOpts = { contentAttributeNames: ['reftext'], locations, inlineParser }
      // read as: reftext='\\\' is rs + sq'
      expect(parse('reftext=\'\\\\\\\' is rs + sq\'', parseOpts)).to.eql(expected)
    })

    it('should set end location for value that ends with escaped backslash to location of escaped backslash', () => {
      const expectedLocation = [{ line: 1, col: 11 }, { line: 1, col: 17 }]
      const expected = {
        reftext: {
          value: 'using \\',
          inlines: [{ name: 'text', type: 'string', value: 'using \\', location: expectedLocation }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      const parseOpts = { contentAttributeNames: ['reftext'], locations, inlineParser }
      // read as: reftext='using \\'
      expect(parse('reftext=\'using \\\\\'', parseOpts)).to.eql(expected)
    })
  })

  describe('attribute references', () => {
    it('should resolve attribute reference before parsing attrlist', () => {
      const attributes = { attrs: 'name=value' }
      const expected = { name: 'value' }
      expect(parse('{attrs}', { attributes })).to.eql(expected)
    })

    it('should resolve attribute references before parsing attrlist', () => {
      const attributes = { attr1: 'name=value', attr2: 'indent=0' }
      const expected = { name: 'value', indent: '0' }
      expect(parse('{attr1},{attr2}', { attributes })).to.eql(expected)
    })

    it('should resolve attribute reference in value of attribute before parsing attrlist', () => {
      const attributes = { desc: 'describe me' }
      const expected = { alt: 'describe me' }
      expect(parse('alt={desc}', { attributes })).to.eql(expected)
    })

    it('should not consider inline passthroughs when resolving attribute references in attrlist', () => {
      const attributes = { value: 'the value' }
      const expected = { name: '+the value+' }
      expect(parse('name=+{value}+', { attributes })).to.eql(expected)
    })

    it('should constrain location on value of content attribute to bounds of attribute reference', () => {
      const title = 'a value longer than the attribute reference'
      const attributes = { title }
      const expected = {
        title: {
          value: title,
          inlines: [{
            name: 'text',
            type: 'string',
            value: 'a value longer than the attribute reference',
            location: [{ line: 2, col: 8 }, { line: 2, col: 14 }],
          }],
        },
      }
      const locations = { 1: { line: 2, col: 2 } }
      expect(parse('title={title}', { attributes, contentAttributeNames: ['title'], locations })).to.eql(expected)
    })

    it('should parse single-quoted content attribute added by attribute reference', () => {
      const titleattr = 'title=\'*TODO* title me\''
      const attributes = { titleattr }
      const expectedLocation = [{ line: 1, col: 3 }, { line: 1, col: 13 }]
      const expected = {
        title: {
          value: '*TODO* title me',
          inlines: [
            {
              name: 'span',
              type: 'inline',
              variant: 'strong',
              form: 'constrained',
              inlines: [{
                name: 'text',
                type: 'string',
                value: 'TODO',
                location: expectedLocation,
              }],
              location: expectedLocation,
            },
            {
              name: 'text',
              type: 'string',
              value: ' title me',
              location: expectedLocation,
            },
          ],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      const parseOpts = { attributes, contentAttributeNames: ['title'], locations, inlineParser }
      expect(parse(',{titleattr}', parseOpts)).to.eql(expected)
    })

    it('should honor passthrough in single-quoted content attribute added by attribute reference', () => {
      const titleattr = 'title=\'+*TODO* title me+\''
      const attributes = { titleattr }
      const expectedLocation = [{ line: 1, col: 2 }, { line: 1, col: 12 }]
      const expected = {
        title: {
          value: '+*TODO* title me+',
          inlines: [{
            name: 'text',
            type: 'string',
            value: '*TODO* title me',
            location: expectedLocation,
          }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      const parseOpts = { attributes, contentAttributeNames: ['title'], locations, inlineParser }
      expect(parse('{titleattr}', parseOpts)).to.eql(expected)
    })

    it('should map location of parsed content attribute added by longer attribute reference', () => {
      const attributes = { 'name-of-attribute': 'title=\'t\'' }
      const expectedLocation = [{ line: 1, col: 2 }, { line: 1, col: 20 }]
      const expected = {
        title: {
          value: 't',
          inlines: [{
            name: 'text',
            type: 'string',
            value: 't',
            location: expectedLocation,
          }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      const parseOpts = { attributes, contentAttributeNames: ['title'], locations, inlineParser }
      expect(parse('{name-of-attribute}', parseOpts)).to.eql(expected)
    })

    it('should not process attribute references when parsing inlines in single-quoted value', () => {
      const titleattr = 'title=\'{as-is}\''
      const attributes = { titleattr, 'as-is': 'should not be used' }
      const expectedLocation = [{ line: 1, col: 2 }, { line: 1, col: 12 }]
      const expected = {
        title: {
          value: '{as-is}',
          inlines: [{
            name: 'text',
            type: 'string',
            value: '{as-is}',
            location: expectedLocation,
          }],
        },
      }
      const locations = { 1: { line: 1, col: 2 } }
      const parseOpts = { attributes, contentAttributeNames: ['title'], locations, inlineParser }
      expect(parse('{titleattr}', parseOpts)).to.eql(expected)
    })
  })
})
