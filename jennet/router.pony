// Copyright 2016 Theodore Butler. All rights reserved.
// Use of this source code is governed by an MIT style
// license that can be found in the LICENSE file.

use "collections"
use "net/http"

class _Router
  let _mux: _Multiplexer
  let _responder: Responder
  let _notfound: _HandlerGroup
  let _host: String

  new val create(mux: _Multiplexer, responder: Responder,
    notfound: _HandlerGroup, host: String)
  =>
    _mux = consume mux
    _responder = responder
    _notfound = notfound
    _host = host

  fun val apply(request: Payload) =>
    (let hg, let c) = try
      (let hg, let params) = _mux(request.method, request.url.path)
      let c = Context(_responder, consume params, _host)
      (hg, consume c)
    else
      (_notfound, Context(_responder, recover Map[String, String] end, _host))
    end
    try
      hg(consume c, consume request)
    end

class _Unavailable
  fun val apply(request: Payload) =>
    let res = Payload.response(StatusServiceUnavailable)
    (consume request).respond(consume res)

class val _Route
  let method: String
  let path: String
  let hg: _HandlerGroup

  new val create(method': String, path': String, hg': _HandlerGroup)
  =>
    method = method'
    path = path'
    hg = hg'
