xquery version "3.0";

module namespace inst= "http://e-smile.org/common/inst";

import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config= "http://e-smile.org/common/config" at "../config.xqm";
import module namespace sm="http://exist-db.org/xquery/securitymanager";

(:~
 : Errors QName 
 :)    
declare variable $inst:ns := "http://e-smile.org/common/inst";
declare variable $inst:ERROR := QName($inst:ns, 'error');


(:~
 : Inst Caller
 :)    
declare
   
function inst:try($node as node(), $model as map(*)) {
    element {node-name($node)} {$node/@*,  
        for $child in $node/node() return
        try{
            <success>{ templates:process($child, $model)}</success>, $child
        } catch * {
            <error>{$err:code || " ... " || $err:description || " ... " || $err:value}</error>, $child
        }
   }
    
};



(:~
 : Groups and Users
 :)    

declare function inst:create-group($node as node(), $model as map(*), $groupname as xs:string, $description as xs:string) {
   if(not(sm:group-exists($groupname))) then sm:create-group($groupname, $description) else "group "||$groupname || " already exists"
};

declare function inst:create-account($node as node(), $model as map(*), $username as xs:string, $password as xs:string, $primarygroup as xs:string, $groups as xs:string) {
    if(not(sm:user-exists($username))) then sm:create-account($username, $password, $primarygroup, $groups) else "user " || $username || " already exists"
};
