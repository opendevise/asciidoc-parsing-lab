/* eslint-env mocha */
'use strict'

import { expect, makeTests, resolveDirname, scanTests, populateASGDefaults, stringifyASG } from '#test-harness'
import parse from 'asciidoc-parsing-lab'
import ospath from 'node:path'

const tests = await scanTests(ospath.join(resolveDirname(import.meta), 'tests/block'))

describe('block', () => {
  makeTests(tests, function ({ input, options, inputPath, expected, expectedWithoutLocations }) {
    let docdir
    if (options?.attributes?.docdir === true) {
      docdir = ospath.dirname(inputPath)
      options = Object.assign({}, options, { attributes: Object.assign({}, options.attributes, { docdir }) })
    }
    const actual = parse(input, options)
    if (docdir && 'docdir' in (actual.attributes ?? {})) {
      Object.keys(actual.attributes).length === 1 ? delete actual.attributes : delete actual.attributes.docdir
    }
    if (expected == null) {
      // Q: can we write data to expect file automatically?
      // TODO only output expected if environment variable is set
      console.log(stringifyASG(actual))
      this.skip()
    } else {
      const msg = `actual output does not match expected output for ${inputPath}`
      expect(actual, msg).to.eql(populateASGDefaults('location' in actual ? expected : expectedWithoutLocations))
    }
  })
})
