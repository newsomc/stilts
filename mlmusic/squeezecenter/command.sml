structure Command = struct

  structure Map = RedBlackMapFn (type ord_key = string
                                 val compare = String.compare)

  (* Render the "now playing" lines at the header. *)

  fun render_header_lines (SOME (_, track :: _)) = (
        case (Map.find (track, "id"), Map.find (track, "title")) of
            (SOME id, SOME title) => "<a href=\"/browse/song/" ^ WebUtil.escapeStr id ^ "/\">"
                                   ^ WebUtil.escapeStr (case Map.find (track, "tracknum") of
                                                            SOME tn => tn ^ ". " ^ title
                                                          | NONE => title)
                                   ^ "</a>"
          | _ => "",
        case (Map.find (track, "album_id"), Map.find (track, "album")) of
            (SOME aid, SOME album) => "<a href=\"/browse/albums/" ^ WebUtil.escapeStr aid ^ "/"
                                    ^ WebUtil.escapeStr album ^ "/\">"
                                    ^ WebUtil.escapeStr album ^ "</a>"
                                    ^ (case Map.find (track, "year") of
                                           SOME y => let val y = WebUtil.escapeStr y
                                                      in " (<a href=\"/browse/years/" ^ y
                                                       ^ "/\">" ^ y ^ "</a>)" end
                                         | NONE => "")
          | _ => "",
        case (Map.find (track, "artist_id"), Map.find (track, "artist")) of
            (SOME aid, SOME artist) => "<a href=\"/browse/artists/" ^ WebUtil.escapeStr aid ^ "/"
                                     ^ WebUtil.escapeStr artist ^ "/\">"
                                     ^ WebUtil.escapeStr artist ^ "</a>"
          | _ => "")
    | render_header_lines _ = ("", "", "")

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

  val conn : CLI.conn option ref = ref NONE

  fun command args = case conn of ref (SOME c) => CLI.command c args
                                | _ => raise Fail "CLI not connected."

  fun players () = let
        val resp = case command [ "players", "0", "9999" ] of
                     ("players"::"0"::"9999"::rest) => rest
                   | _ => raise Fail "unexpected result" 
      in
        mapMulti "playerindex" resp
      end

  fun cachedir () = 
        case command [ "pref", "server:cachedir", "?" ] of
          [ "pref", "server:cachedir", dir ] => dir
        | _ => raise Fail "could not find server cachedir: unexpected result"

  structure JSON = struct

    fun string s = "\"" ^ String.toString s ^ "\""

    fun list l = "[" ^ String.concatWith "," (map string l) ^ "]"

    fun object map = let
          fun process (k, v, acc) = (string k ^ ":" ^ string v) :: acc
        in
          "{" ^ String.concatWith "," (Map.foldli process nil map) ^ "}"
        end
  end

  fun statusRaw p = let
        val resp = case command [ p, "status", "-", "1", "tags:asledity" ] of 
                     (_::"status"::"-"::"1"::"tags:asledity"::rest) => rest
                   | _ => raise Fail "unexpected result" 
      in
        mapMulti "playlist index" resp
      end

  fun statusJSON NONE = "null"
    | statusJSON (SOME (prologue, tracks)) = let
        val (ti, ar, al) = render_header_lines (SOME (prologue, tracks))
      in
        "[" ^ JSON.object (mapResp prologue)
            ^ ",[" ^ String.concatWith "," (map JSON.object tracks) ^ "]"
            ^ ",[" ^ JSON.string ti ^ "," ^ JSON.string ar ^ "," ^ JSON.string al ^ "]]"
      end

  fun extractTrack m = let
        fun get key = case Map.find (m, key) of SOME s => s
                                              | NONE => ""
      in {
        id = get "id", tracknum = Map.find (m, "tracknum"), title = get "title",
        album = case (Map.find (m, "album_id"), Map.find (m, "album")) of
                  (SOME i, SOME a) => SOME { id = i, name = a } | _ => NONE,
        artists = case (Map.find (m, "artist_id"), Map.find (m, "artist")) of
                  (SOME i, SOME a) => [ { id = i, name = a } ] | _ => nil,
        lossless = NONE, ct = NONE, bitrate = NONE
      } end

  fun playlist p start len = let
        val resp = case command [ p, "status", Int.toString start,
                                        Int.toString len, "tags:asledity" ] of 
                     (_::"status"::_::_::"tags:asledity"::rest) => rest
                   | _ => raise Fail "unexpected result" 
        val (prologue, tracks) = mapMulti "playlist index" resp
      in
        (prologue, map extractTrack tracks)
      end




end
