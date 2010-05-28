function log(str) {
    if (("console" in window) && ("firebug" in console)) {
	console.log(str);
    }	
}

var txns = new Array();
function txn(id,txt) {
    txns[id] = txt;
}

var strings = new Array();
function dude(id,type,email,name) {
    if (!strings[type]) {
	strings[type] = new Array();
    }
    strings[type].push([email, id]);
    strings[type].push([name, id]);
}

var accounts = new Array();
function account(id,type,name) {
    if (!accounts[type]) {
	accounts[type] = new Array();
    }
    accounts[type].push([id, name]);
}

function init_consolidate() {
    //    log("init!");
}

function changetype(id) {
    log("Changed "+id);

    // Get the current account type to look for:
    var typeinput    = document.getElementById("type_"+id);
    var accountinput = document.getElementById("account_"+id);
    accountinput.options.length=0;   
    accountinput.options[accountinput.options.length] = 
	new Option('Unknown', 0, false, false);

    var text = txns[id];
    var type = typeinput.value;
    var acc = accounts[type];
    if (acc) {
	
	var match = 0;
	if (strings[type]) {
	    for (var j=0;j<strings[type].length;j++) {
		if (text.indexOf(strings[type][j][0]) >= 0) {
		    match = strings[type][j][1];
		    log("Found account "+match+" matching "+text);
		}
	    }
	}

	for (var i=0;i<acc.length;i++) {
	    var a = acc[i];

	    accountinput.options[accountinput.options.length] = 
		new Option(a[1], a[0], false, match == a[0]);
	}
    } else {
	log("No accounts of type: "+typeinput.value);
    }    
}

