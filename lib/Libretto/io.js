/*

io.js

*/

function open(FILENAME){
	var file_extension = FILENAME.split(".").pop();
	if(file_extension=="zip"){
		return new Zip(FILENAME);
	} else if(isfile(FILENAME)){
		return new File(FILENAME);
	} else if(isdir(FILENAME)){
		return new Directory(FILENAME);
	} else {
		return undefined;
	}
}

var Zip = (function () {
	function Zip(ZipName) {
		this.Name = ZipName;
		this._exists = isfile(ZipName);
		this._zipid = zopen(ZipName);
		this._addedFiles = new Array();

		this.Extract = function(Directory){
			if(zextract(this._zipid,Directory)){
				return true;
			} else {
				return false;
			}
		}

		this.Close = function(){
			zclose(this._zipid);
		}

		this.Member = function (Member){
			return zmember(this._zipid,Member);
		}

		this.Remove = function(Member){
			if(zremove(this._zipid,Member)){
				return true;
			} else {
				return false;
			}
		}

		this.Write = function(){
			if(zwrite(this._zipid)){
				return true;
			} else {
				return false;
			}
		}

		this.Add = function(Filename){
			if(this._addedFiles.indexOf(Filename) > -1 ){
				return true;
			} 
			if(zadd(this._zipid,Filename)){
				this._addedFiles.push(Filename);
				return true;
			} else {
				return false;
			}
		}
	}

	Object.defineProperty(Zip.prototype, "Files", {
		get: getFiles
	});

	Object.defineProperty(Zip.prototype, "Exists", {
		get: getExists
	});

	return Zip;

	function getExists(){
		return this._exists;
	}

	function getFiles(){
		if(this._exists){
			var fl = new Array();
			fl = zlist(this.Name);
			return fl;
		} else {
			return false;
		}
	}
})();


var Directory = (function () {
	function Directory(DirectoryName) {
		this.Name = DirectoryName;
		this._exists = isdir(Filename);
	}

	Object.defineProperty(Directory.prototype, "Files", {
		get: getFiles
	});

	Object.defineProperty(Directory.prototype, "Exists", {
		get: getExists
	});

	return Directory;

	function getExists(){
		return this._exists;
	}

	function getFiles(){
		if(this._exists){
			var fl = new Array();
			fl = dirlist(this.Name);
			return fl;
		} else {
			return false;
		}
	}
})();

var File = (function () {
	function File(Filename) {
		this.Name = Filename;
		this._contents = fread(Filename);
		this._exists = isfile(Filename);
		this._permissions = fpermissions(Filename);

		this.Save = function(){
			if(fwrite(this.Name,this._contents)){
				this._exists = true;
				this._permissions = fpermissions(Filename);
				return true;
			}
			return false;
		}

		this.Delete = function(){
			if(rmfile(this.Name)){
				this._exists = false;
				this._permissions = "";
				return true;
			}
			return false;
		}

		this.Append = function(data){
			this._contents = this._contents + data;
		}
	}

	Object.defineProperty(File.prototype, "Contents", {
		get: getContents,
		set: setContents
	});

	Object.defineProperty(File.prototype, "Exists", {
		get: getExists
	});

	Object.defineProperty(File.prototype, "Mode", {
		get: getMode,
		set: setMode
	});

	Object.defineProperty(File.prototype, "Read", {
		get: getCanRead
	});

	Object.defineProperty(File.prototype, "Write", {
		get: getCanWrite
	});

	Object.defineProperty(File.prototype, "Execute", {
		get: getCanExecute
	});

	Object.defineProperty(File.prototype, "Size", {
		get: getSize
	});

	Object.defineProperty(File.prototype, "SHA256", {
		get: getSHA256
	});

	Object.defineProperty(File.prototype, "SHA512", {
		get: getSHA512
	});

	Object.defineProperty(File.prototype, "Base64", {
		get: getBase64
	});

	Object.defineProperty(File.prototype, "Basename", {
		get: getBasename
	});

	Object.defineProperty(File.prototype, "Location", {
		get: getLocation
	});

	return File;

	function getLocation(){
		if(this._exists){
			return flocation(this.Name);
		} else {
			return undefined;
		}
	}

	function getBasename(){
		if(this._exists){
			return basename(this.Name);
		} else {
			return undefined;
		}
	}

	function getBase64(){
		return base64(this._contents);
	}

	function getSHA512(){
		return sha512(this._contents);
	}

	function getSHA256(){
		return sha256(this._contents);
	}

	function getSize(){
		if(this._exists){
			return fsize(this.Name);
		} else {
			return this._contents.length;
		}
	}

	function getCanWrite(){
		if(this._permissions.indexOf("w") !== -1){
		  return true;
		}
		return false;
	}

	function getCanExecute(){
		if(this._permissions.indexOf("x") !== -1){
			return true;
		}
		return false;
	}

	function getCanRead(){
		if(this._permissions.indexOf("r") !== -1){
			return true;
		}
		return false;
	}

	function getMode(){
		return fmode(this.Name);
	}

	function setMode(x){
		if(chmod(this.Name,x)){
			this._permissions = fpermissions(Filename);
		}
	}

	function getContents() { 
		return this._contents;
	}

	function setContents(x) {
		this._contents = x;
	}

	function getExists() { 
		return this._exists;
	}

})();
