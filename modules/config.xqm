xquery version "3.0";

(:~
 : A set of helper functions to access the application context from
 : within a module.
 :)
module namespace config="http://e-smile.org/es-admin/config";

declare namespace templates="http://exist-db.org/xquery/templates";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";
declare namespace resource-map = "http://e-smile.org/common/resource-map"; 

(: 
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

declare variable $config:data-root := $config:app-root || "/data";

declare variable $config:repo-descriptor := doc(concat($config:app-root, "/repo.xml"))/repo:meta;

declare variable $config:expath-descriptor := doc(concat($config:app-root, "/expath-pkg.xml"))/expath:package;

declare variable $config:path-configuration := $config:app-root|| "/configuration.xml";

declare variable $config:resource-map := doc(concat($config:app-root, "/resource-map.xml"))/resource-map:root;

declare variable $config:SETTINGS := doc($config:app-root || "/configuration.xml")/*;
declare variable $config:REPO := $config:SETTINGS//repository[not(@active = 'false')];
declare variable $config:DEFAULTREPO := xs:anyURI(($config:REPO[@default="true"], $config:REPO)[1]/url);
(:~
 : Resolve the given path using the current application context.
 : If the app resides in the file system,
 :)
declare function config:resolve($relPath as xs:string) {
    if (starts-with($config:app-root, "/db")) then
        doc(concat($config:app-root, "/", $relPath))
    else
        doc(concat("file://", $config:app-root, "/", $relPath))
};

(:~
 : Returns the repo.xml descriptor for the current application.
 :)
declare function config:repo-descriptor() as element(repo:meta) {
    $config:repo-descriptor
};

(:~
 : Returns the expath-pkg.xml descriptor for the current application.
 :)
declare function config:expath-descriptor() as element(expath:package) {
    $config:expath-descriptor
};

declare %templates:wrap function config:app-title($node as node(), $model as map(*)) as text() {
    $config:expath-descriptor/expath:title/text()
};


declare function config:app-meta($node as node(), $model as map(*)) as element()* {
    <meta xmlns="http://www.w3.org/1999/xhtml" name="description" content="{$config:repo-descriptor/repo:description/text()}"/>,
    for $author in $config:repo-descriptor/repo:author
    return
        <meta xmlns="http://www.w3.org/1999/xhtml" name="creator" content="{$author/text()}"/>
};

(:~
 : For debugging: generates a table showing all properties defined
 : in the application descriptors.
 :)
declare function config:app-info($node as node(), $model as map(*)) {
    let $expath := config:expath-descriptor()
    let $repo := config:repo-descriptor()
    return
        <table class="app-info">
            <tr>
                <td>app collection:</td>
                <td>{$config:app-root}</td>
            </tr>
            {
                for $attr in ($expath/@*, $expath/*, $repo/*)
                return
                    <tr>
                        <td>{node-name($attr)}:</td>
                        <td>{$attr/string()}</td>
                    </tr>
            }
            <tr>
                <td>Controller:</td>
                <td>{ request:get-attribute("$exist:controller") }</td>
            </tr>
        </table>
};

(:~
 : Returns the document element for the path relative to this application 
 :)    
declare function config:doc($path as xs:string) {
    doc( $config:app-root || '/' ||  $path)/*
};

(:~
 : Monitoring Space Configuation 
 : configuration file for the account instance
 :)      
 declare function config:conf() {
    doc($config:path-configuration)/*
 };
 
 declare function config:app-state() {
   config:conf()//state
 };
 
 declare function config:app-key() {
   data(config:conf()//appKey)
 };
 declare function config:public-key() {
   data(config:conf()//publicKey)
 };
declare function config:app-abbrev() as text() {
    data($config:expath-descriptor/@abbrev)
};

 declare function config:app-name() {
   tokenize(config:repo-descriptor()//repo:target,"/")[last()]
 };
 
  declare function config:app-mode() {
   data(config:conf()//mode)
 };
 
 declare function config:date-format() {
     data(config:conf()//dateFormat)
 };
