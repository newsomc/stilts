structure Wiki = struct

  structure U = WebUtil
  structure RE = RegExpFn (structure P = AwkSyntax
                           structure E = BackTrackEngine)

  fun formatPage page = let

        fun getMatch { pos, len } = Substring.string (Substring.slice (pos, 0, SOME len))

        fun makeLink s = "<a href=\"" ^ s ^ "\">" ^ s ^ "</a>"

        val translateCR = String.translate (fn #"\n" => "<br />"
                                             | c => String.str c) 

        val match = RE.match [ ("\\[([A-Za-z]*)\\]", fn m =>
                                  makeLink (getMatch (MatchTree.nth (m, 1)))),
                               ("[^\\[]+", fn m => let
                                  val match = getMatch (MatchTree.root m)
                                in        
                                  translateCR (WebUtil.escapeStr match)
                                end) 
                             ]
                             Substring.getc

        fun loop s = case match s of NONE => nil
                               | SOME (res, s') => res :: (loop s')
      in
        Web.HTML (String.concat (loop (Substring.full page)))
     end

  fun handler (req: Web.request) = (case U.postpath req of

        nil =>
          raise U.redirectPostpath req [ "MainPage" ]

      | [ "" ] =>
          raise U.redirectPostpath req [ "MainPage" ]

      | [ title ] => U.htmlResp (
            case SQL.getPage title of
              SOME { id, text } => TPage.render { title = title,
                                                  body = formatPage text }
            | NONE => raise U.redirectPostpath req [ title, "edit" ]
          )

      | [ title, "edit" ] => U.htmlResp (
            TEditPage.render (
              case SQL.getPage title of
                SOME { id, text } => { title = title, text = text, new = false }
              | NONE => { title = title, text = "", new = true } )
          )

      | [ title, "save" ] =>
            let
              val form = Form.load req
              val content = valOf (Form.get form "content")
                    handle Option => raise U.redirectPostpath req [ title ]
            in
              case Form.get form "new" of
                SOME _ => SQL.createPage { title = title, text = content }
              | NONE => SQL.updatePage { title = title, text = content };

              raise U.redirectPostpath req [ title ]
            end

      | _ => raise U.notFound
    )
(*
  val conn_info : MySQLClient.connect_info = {
        host = NONE, port = 0w0, unix_socket = NONE,
        user = SOME "root", password = NONE, db = SOME "foowiki"
      }

  val conn = MySQLClient.init ()

  val () = (MySQLClient.real_connect conn conn_info;
            SQL.conn := SOME conn)
*)
  val () = SQL.prepare (SQLite.opendb "wiki.db")

  val app = U.dumpRequestWrapper print (U.exnWrapper handler)

  fun main _ = let
      val () = print "Listening...\n"
      val serverthread = HTTPServer.spawn_server (INetSock.any 5124) app
    in
      T.run ();
      0
    end

end
