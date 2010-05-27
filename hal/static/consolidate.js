function log(str) {
    if (("console" in window) && ("firebug" in console)) {
	console.log(str);
    }	
}


function init_consolidate() {
    log("init!");
}

function changetype(id) {
    log("Changed "+id);
    
    
}