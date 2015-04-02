/* File BlockUtils.i */
/*
////////////////////////////////////////////////////////////////////////////////
//                                                                            //
//  Copyright (C) 2011-2014, Armory Technologies, Inc.                        //
//  support@bitcoinarmory.com                                                 //
//  Distributed under the GNU Affero General Public License (AGPL v3)         //
//  See LICENSE or http://www.gnu.org/licenses/agpl.html                      //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////
*/
%module(directors="1") CppBlockUtils
%feature("director") BDM_CallBack;
%feature("director") BDM_Inject;

%{
#define SWIG_PYTHON_EXTRA_NATIVE_CONTAINERS
#include "BlockObj.h"
#include "BlockUtils.h"
#include "BtcUtils.h"
#include "EncryptionUtils.h"
#include "BtcWallet.h"
#include "LedgerEntry.h"
#include "ScrAddrObj.h"
#include "Blockchain.h"
#include "BDM_mainthread.h"
#include "BlockDataManagerConfig.h"
#include "BlockDataViewer.h"
%}


%include "std_string.i"
%include "std_vector.i"
%include "std_set.i"
%include "std_map.i"
%include "std_shared_ptr.i"
%include "exception.i"

%typedef std::string string;
%typedef unsigned char      uint8_t;
%typedef unsigned short     uint16_t;
%typedef unsigned int       uint32_t;
%typedef unsigned long long uint64_t;
%typedef char               int8_t;
%typedef short              int16_t;
%typedef int                int32_t;
%typedef long long          int64_t;
%typedef unsigned int       size_t;
%typedef unsigned int       TXIN_SCRIPT_TYPE;
%typedef unsigned int       TXOUT_SCRIPT_TYPE;

%ignore readVarInt(BinaryRefReader & brr);
%ignore BlockDataViewer::blockchain() const;
%ignore BlockDataManager_LevelDB::readBlockUpdate(const pair<size_t, uint64_t>& headerOffset);
%ignore BlockDataManager_LevelDB::loadDiskState(const function<void(unsigned, double,unsigned)> &progress);
%ignore BlockDataViewer::refreshLock_;


%allowexception;

namespace std
{
   %template(vector_int) std::vector<int>;
   %template(vector_float) std::vector<float>;
   %template(vector_string) std::vector<string>;
   //%template(vector_BinaryData) std::vector<BinaryData>;
   %template(vector_LedgerEntry) std::vector<LedgerEntry>;
   //%template(vector_LedgerEntryPtr) std::vector<const LedgerEntry*>;
   %template(vector_TxRefPtr) std::vector<TxRef*>;
   %template(vector_Tx) std::vector<Tx>;
   %template(vector_BlockHeaderPtr) std::vector<BlockHeader>;
   %template(vector_UnspentTxOut) std::vector<UnspentTxOut>;
   %template(vector_AddressBookEntry) std::vector<AddressBookEntry>;
   %template(vector_RegisteredTx) std::vector<RegisteredTx>;
   %template(shared_ptr_BtcWallet) std::shared_ptr<BtcWallet>;
   %template(set_BinaryData) std::set<BinaryData>;
}

%exception
{
	try
	{
		$function
	}
	catch (std::exception& e)
	{
		SWIG_exception(SWIG_RuntimeError, e.what());
	}
}


/******************************************************************************/
/* Convert Python(str) to C++(BinaryData) */
%typemap(in) BinaryData
{
   if(!PyString_Check($input))
   {
      PyErr_SetString(PyExc_ValueError, "Expected string argument!");
      return NULL;
   }
   
   $1 = BinaryData((uint8_t*)PyString_AsString($input), PyString_Size($input));
}

/******************************************************************************/
/* Convert C++(BinaryData) to Python(str) */
%typemap(out) BinaryData
{
   $result = PyString_FromStringAndSize((char*)($1.getPtr()), $1.getSize());
}

/* Convert C++(const BinaryDataRef) to Python(str) */
%typemap(out) const BinaryDataRef
{
   $result = PyString_FromStringAndSize((char*)($1.getPtr()), $1.getSize());
}
/******************************************************************************/
/*
// Convert Python(str) to C++(BinaryData const &) 
// We add a bdObj which will get created outside the typemap block,
// so that we have a BinaryData obj that isn't destroyed before it 
// is referenced (search CppBlockUtils_wrap.cxx for "bdObj")
*/
%typemap(in) BinaryData const & (BinaryData bdObj)
{
   if(!PyString_Check($input))
   {
      PyErr_SetString(PyExc_ValueError, "Expected string argument!");
      return NULL;
   }
   bdObj.copyFrom((uint8_t*)PyString_AsString($input), PyString_Size($input));
   $1 = &bdObj;
}

/******************************************************************************/
/* Convert C++(BinaryData const &) to Python(str) */
%typemap(out) BinaryData const & 
{
   $result = PyString_FromStringAndSize((char*)($1->getPtr()), $1->getSize());
}

/******************************************************************************/
// Convert Python(list[string]) to C++(vector<BinaryData>) 
%typemap(in) const std::vector<BinaryData> & (std::vector<BinaryData> bdObjVec)
{
	for(int i=0; i<PyList_Size($input); i++)
	{
		PyObject* strobj = PyList_GetItem($input, i);
		
		BinaryData bdStr((uint8_t*)PyString_AsString(strobj), PyString_Size(strobj));

		bdObjVec.push_back(bdStr);
	}

	$1 = &bdObjVec;
}

/******************************************************************************/
// Convert C++(vector<BinaryData>) to Python(list[string])
%typemap(out) vector<BinaryData>
{
	vector<BinaryData>::iterator bdIter = $1.begin();
	PyObject* thisList = PyList_New($1.size());
	int i=0;

	while(bdIter != $1.end())
	{
		BinaryData & bdobj = (*bdIter);
		
		PyObject* thisPyObj = PyString_FromStringAndSize((char*)(bdobj.getPtr()), bdobj.getSize());

		PyList_SET_ITEM(thisList, i, thisPyObj);

		++i;
		++bdIter;
	}

	$result = thisList;
}

/******************************************************************************/
// Convert C++(set<BinaryData>) to Python(list[string])
%typemap(out) set<BinaryData>
{
	set<BinaryData>::iterator bdIter = $1.begin();
	PyObject* thisList = PyList_New($1.size());
	int i=0;

	while(bdIter != $1.end())
	{
		auto& bdobj = (*bdIter);
		
		PyObject* thisPyObj = PyString_FromStringAndSize(bdobj.getCharPtr(), bdobj.getSize());

		PyList_SET_ITEM(thisList, i, thisPyObj);

		++i;
		++bdIter;
	}

	$result = thisList;
}

/******************************************************************************/
// Convert Python(dict{str:list[str]}) to C++(map<BinaryData, vector<BinaryData>) 
%typemap(in) const std::map<BinaryData, std::vector<BinaryData> >& (std::map<BinaryData, std::vector<BinaryData> > map_bd_vec_bd)
{
	PyObject *key, *value;
	Py_ssize_t pos = 0;

	while(PyDict_Next($input, &pos, &key, &value))
	{
		BinaryData wltIDStr((uint8_t*)PyString_AsString(key), PyString_Size(key));
		std::vector<BinaryData> bdObjVec;

		for(int i=0; i<PyList_Size(value); i++)
		{
			PyObject* strobj = PyList_GetItem(value, i);
		
			BinaryData bdStr((uint8_t*)PyString_AsString(strobj), PyString_Size(strobj));

			bdObjVec.push_back(bdStr);
		}

		map_bd_vec_bd.insert(std::make_pair(wltIDStr, std::move(bdObjVec)));
	}
	$1 = &map_bd_vec_bd;
}

/******************************************************************************/
// Convert C++(StoredHeader) to a Python dict with the following key:val pairs:
// {
// "height":int
// "blockHash":str
// "merkle":str
// "numBytes":int
// "numTx":int
// "txHashList":[TxHash, TxHash, TxHash, ...]
// }
%typemap(out) StoredHeader
{
	PyObject *thisDict = PyDict_New();

	//height
	PyDict_SetItemString(thisDict, "height", PyInt_FromSize_t($1.blockHeight_));

	//block hash
	std::string hashStr = $1.thisHash_.toHexStr(true);
	PyDict_SetItemString(thisDict, "blockHash", 
		PyString_FromStringAndSize(hashStr.c_str(), hashStr.size()));

	//merkle
	std::string merkleStr = $1.merkle_.toHexStr(true);
	PyDict_SetItemString(thisDict, "merkle", 
		PyString_FromStringAndSize(merkleStr.c_str(), merkleStr.size()));

	//size of block in bytes
	PyDict_SetItemString(thisDict, "numBytes", PyInt_FromSize_t($1.numBytes_));

	//tx count
	PyDict_SetItemString(thisDict, "numTx", PyInt_FromSize_t($1.getNumTx()));

	PyObject *thisList = PyList_New($1.getNumTx());
	
	//tx hash list
	for(unsigned i=0; i<$1.getNumTx(); i++)
	{
		DBTx& tx = $1.getTxByIndex(i);
		std::string hashStr = tx.thisHash_.toHexStr(true);
		PyList_SET_ITEM(thisList, i, 
			PyString_FromStringAndSize(hashStr.c_str(), hashStr.size()));
	}

	//add list to dict
	PyDict_SetItemString(thisDict, "txHashList", thisList);

	$result = thisDict;
}

// Ubuntu 12.04 doesn't support C++11 without compiler & linker trickery. One
// very tricky issue involves librt. clock_* calls required the rt library
// before GLIBC 2.17, at which point they were moved to libc. Long story short,
// Ubuntu 12.04 can't compile C++11 by default (only GCC 4.6 is available by
// default, and a libstdc++ bug means GCC 4.7.3+ must be used), and making a
// 12.04 build under later versions of Ubuntu (with static linking) creates a
// hole due to glibc 2.17+ being present post-12.04. SWIG somehow gets tripped
// up, as seen if compiling Armory with the "-Wl,--no-undefined" linker flag. To
// fix this, create a dummy call in the SWIG-generated code that forces an rt
// link in SWIG. This marks the appropriate library as "NEEDED" by the linker.
// The alternative - using the "-Wl,--no-as-needed" linker flag - is brute
// force and can cause bloat by adding unneeded libraries if devs aren't
// careful. (Also, this only affects Linux.)
%inline %{
#if defined(__linux) || defined(__linux__)
   void force_librt() { timer_create(CLOCK_REALTIME, NULL, NULL); }
#endif
%}

/* With our typemaps, we can finally include our other objects */
%include "BlockObj.h"
%include "BlockUtils.h"
%include "BtcUtils.h"
%include "EncryptionUtils.h"
%include "BtcWallet.h"
%include "LedgerEntry.h"
%include "ScrAddrObj.h"
%include "Blockchain.h"
%include "BlockDataViewer.h"
%include "BlockDataManagerConfig.h"
%include "BDM_mainthread.h"
%include "bdmenums.h"
