xquery version "3.0";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace repo="http://exist-db.org/xquery/repo";
 
(:import module namespace config="http://e-smile.org/es-admin/config" at "../config.xqm";:)
(:import module namespace app="http://e-smile.org/es-admin/templates" at "../app.xql";:)
import module namespace packages="http://e-smile.org/es-admin/packages" at "../../../common/modules/packages.xqm";


(:declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";:)
(:declare option output:method "json";:)
(:declare option output:media-type "application/json";:)

let $type := request:get-parameter("type", "all")
let $format := request:get-parameter("format", "esmileApp")

(:return <div>Je;p</div>:) 
let $ret := packages:get( $type, $format,())
(:[.//name = 'http://e-smile.org/ms/theme-PeaceSupportTransition']:)
return 
  <root>{$ret}</root>