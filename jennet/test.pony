use "collections"
use "itertools"
use "ponytest"

actor Main is TestList
  new create(env: Env) =>
    PonyTest(env, this)

  fun tag tests(test: PonyTest) =>
    test(_TestLexPath)
    test(_TestMuxTree)

class iso _TestLexPath is UnitTest
  fun name(): String => "Test _LexPath"

  fun apply(h: TestHelper) =>
    let tests =
      [ as (String, Array[_PathTok]):
        ("/foo", ["foo"])
        ("foo", ["foo"])
        ("/foo/bar", ["foo"; "bar"])
        ("/foo//bar/", ["foo"; "bar"])
        ("/:foo", [_ParamTok("foo")])
        ("/:foo/", [_ParamTok("foo")])
        ("/:foo/bar", [_ParamTok("foo"); "bar"])
        ("/foo/bar", ["foo"; "bar"])
        ("/:foo/:bar", [_ParamTok("foo"); _ParamTok("bar")])
        ("/:foo/bar/*baz", [_ParamTok("foo"); "bar"; _WildTok("baz")])
        ("/*baz", [_WildTok("baz")])
      ]

    let tok_eq =
      {(toks: (_PathTok, _PathTok)) =>
        match toks
        | (let s1: String, let s2: String) =>
          h.assert_eq[String](s1, s2)
        | (let p1: _ParamTok, let p2: _ParamTok) =>
          h.assert_eq[String](p1.name, p2.name)
        | (let w1: _WildTok, let w2: _WildTok) =>
          h.assert_eq[String](w1.name, w2.name)
        else
          h.fail("unequal token types")
        end
      }

    for (path, toks) in tests.values() do
      let out = _LexPath(path)
      h.assert_eq[USize](toks.size(), out.size())
      Iter[_PathTok](toks.values())
        .zip[_PathTok](out.values())
        .map[None](tok_eq)
        .run()
    end

// TODO UTF8 support
class iso _TestMuxTree is UnitTest
  fun name(): String => "Test _MuxTree"

  fun apply(h: TestHelper) ? =>
    _run_tests(h,
      [ ("/foo/:bar/baz", 1)
        ("/fiz/:bar/baz", 2)
        // ("/foo/biz/baz", 3)
      ],
      [ ("/foo/bar/baz", 1, [("bar", "bar")])
        ("/fiz/bar/baz", 2, [("bar", "bar")])
      ])?
    _run_tests(h,
      [ ("/", 0)
        ("/foo", 1)
        ("/:foo", 2)
        ("/foo/bar/", 3)
        ("/baz/bar", 4)
        ("/:foo/baz", 5)
        ("/foo/bar/*baz", 6)
        // ("/fi", 7)
        // ("/fizz", 8)
      ],
      [ ("/", 0, [])
        ("/foo", 1, [])
        ("/stuff", 2, [("foo", "stuff")])
        ("/a", 2, [("foo", "a")])
        ("/1", 2, [("foo", "1")])
        ("/foo/bar/", 3, [])
        // ("/foo/bar", -1, []) // TODO strict trailing slash
        ("/baz/bar", 4, [])
        ("/stuff/baz", 5, [("foo", "stuff")])
        // ("/stuff/baz/", -1, []) // TODO strict trailing slash
        ("/foo/bar/stuff/and/things", 6, [("baz", "stuff/and/things")])
        ("/foo/bar/a", 6, [("baz", "a")])
        ("/foo/bar//", 3, []) // TODO should this be configurable?
        // ("/fi", 7, [])
        // ("/fizz", 8, [])
      ])?

  fun _run_tests(
    h: TestHelper,
    routes: Array[(String, U8)],
    tests: Array[(String, U8, Array[(String, String)])]) ?
  =>
    let mux = _MuxTree[U8](routes(0)?._1, routes(0)?._2)
    for (path, n) in routes.slice(1).values() do
      mux.add_route(_LexPath(path), n)?
    end

    for (path, n, params) in tests.values() do
      if n == -1 then
        h.assert_error({()? => mux.get_route(path, recover _Vars end)? })
      else
        (let n', let params') = mux.get_route(path, recover _Vars end)?
        h.assert_eq[U8](n, n')
        h.assert_eq[USize](params.size(), params'.size())
        for (param, value) in params.values() do
          h.assert_eq[String](params'(param)?, value)
        end
      end
    end
