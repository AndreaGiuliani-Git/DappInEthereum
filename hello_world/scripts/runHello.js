var HelloWorld = artifacts.require("Helloworld");

module.exports = async function(callback) {
    try {
        let hello_deployed = await HelloWorld.deployed();
        let greet= process.argv[4];
        const message = await hello_deployed.sayHello(greet);
        console.log(message);
    }
    catch(error){
        console.log("ERROR: "+ error);
    }
    callback();
}