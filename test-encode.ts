const packet = require('dns-packet')

const hexEncodeName = (name) => {
    return '0x' + packet.name.encode(name).toString('hex')
}


console.log("testccip9.eth", hexEncodeName("testccip9.eth"));
console.log("meta.testccip9.eth", hexEncodeName("meta.testccip9.eth"));
console.log("meta.testccip9.unruggable", hexEncodeName("meta.testccip9.unruggable"));

process.exit();

function hexStringToByteArray(hexString) {
    if (hexString.length % 2 !== 0) {
        throw "Must have an even number of hex digits to convert to bytes";
    }
    var numBytes = hexString.length / 2;
    var byteArray = new Uint8Array(numBytes);
    for (var i=0; i<numBytes; i++) {
        byteArray[i] = parseInt(hexString.substr(i*2, 2), 16);
    }
    return byteArray;
}

const decodedName = new TextDecoder().decode(hexStringToByteArray("0x04746573740874657374636369700a756e7275676761626c6500"));

function tidy(s) {
  const tidy = typeof s === 'string'
    ? s.replace( /[\x00-\x1F\x7F-\xA0]+/g, '.' )
    : s ;
  return tidy;
}

const tidiedName = tidy(decodedName).slice(1,-1);

console.log(tidiedName);

