structure Command = struct

  structure Map = RedBlackMapFn (type ord_key = string
                                 val compare = String.compare)

  fun foldMap (str, map) = let
        val str' = Substring.full str
        val (ls, rs) = Substring.splitl (fn c => c <> #":") str'
      in
        Map.insert (map, Substring.string ls,
                         Substring.string (Substring.triml 1 rs))
      end

  val mapResp = foldl foldMap Map.empty

  fun mapMulti prefix list = let

        val prefix' = prefix ^ ":"

        fun split (nil, curChunk, chunks) = curChunk :: chunks
          | split (s::rest, curChunk, chunks) =
              if String.isPrefix prefix' s
              then split (rest, nil, (s :: curChunk) :: chunks)
              else split (rest, s :: curChunk, chunks)

        val (prologue, items) = case split (rev list, nil, nil) of
              (prologue :: items) => (prologue, items)
            | _ => raise Fail "unexpected result"

 
      in
        (prologue, map (foldl foldMap Map.empty) items)
      end

  val c = CLI.connect ("localhost", 9090)

  fun players () = let
        val resp = case CLI.command c [ "players", "0", "9999" ] of
                     ("players"::"0"::"9999"::rest) => rest
                   | _ => raise Fail "unexpected result" 
      in
        mapMulti "playerindex" resp
      end

  fun status p = let
        val resp = case CLI.command c [ p, "status" ] of 
                     (_::"status"::rest) => rest
                   | _ => raise Fail "unexpected result" 
        fun jsonify (k, v, acc) =
              ("\"" ^ String.toString k ^ "\":\"" ^ String.toString v ^ "\"")
              :: acc
        val kv = Map.foldli jsonify nil (mapResp resp)
      in
        "{" ^ String.concatWith "," kv ^ "}"
      end

end
