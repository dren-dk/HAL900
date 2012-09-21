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

function addAccounts(type, ctrl) {
    // Get the current account type to look for:
    var accountinput = document.getElementById(ctrl);
//    accountinput.options.length=0;   
    accountinput.options[accountinput.options.length] = new Option('Unknown', 0, false, false);

    var acc = accounts[type];
    if (acc) {	
	for (var i=0;i<acc.length;i++) {
	    var a = acc[i];
	    accountinput.options[accountinput.options.length] = new Option(a[1], a[0], false, false);
	}
    } else {
	log("No accounts of type: "+typeinput.value);
    }    
}

function init_rain() {
    addAccounts(2, "source_account");
    addAccounts(4, "target_account");
    addAccounts(5, "target_account");
}

