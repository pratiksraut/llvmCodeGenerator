%{
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <list>
#include <map>
 #include <iostream> 
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Support/FileSystem.h"

using namespace llvm;
using namespace std;

extern FILE *yyin;
int yylex(void);
int yyerror(const char *);

// From main.cpp
extern char *fileNameOut;
extern Module *M;
extern LLVMContext TheContext;
extern Function *Func;
extern IRBuilder<> Builder;

// Used to lookup Value associated with ID
map<string,Value*> idLookup;
 
%}

%union {
  int num;
  char *id;
  Value* val;
  std::list<Value*> *valueList;
}

%token IDENT NUM MINUS PLUS MULTIPLY DIVIDE LPAREN RPAREN SETQ SETF AREF MIN MAX ERROR MAKEARRAY

%type <num> NUM 
%type <id> IDENT
%type <val> exprlist token token_or_expr expr program
%type <valueList> token_or_expr_list

%start program

%%


/*
   IMPLMENT ALL THE RULES BELOW HERE!
 */

program : exprlist 
{ 
  /* 
    IMPLEMENT: return value
    Hint: the following code is not sufficient
  */
    //Builder.CreateRet(Builder.getInt32(0));
  Builder.CreateRet($1);
  
  return 0;
}
;

exprlist:  exprlist expr 
{
	$$ = $2;
}
| expr // MAYBE ADD ACTION HERE?
{
	$$ = $1;
}
;         

expr: LPAREN MINUS token_or_expr_list RPAREN
{ 
 	Value* result = Builder.getInt32(0);
	std::list<Value*>::iterator it = $3->begin();
	if($3->size() == 1)
	{
		result = Builder.CreateNeg(*it);
	}
	else
	{
		std::cout << "syntax error for MINUS" << endl;
			YYABORT;
	}
	$$ = result;
}
| LPAREN PLUS token_or_expr_list RPAREN
{	
	Value* result = Builder.getInt32(0);
	for(std::list<Value*>::iterator it=$3->begin(); it!= $3->end(); ++it)
	{
		result = Builder.CreateAdd(result, *it);
	}
	$$ = result;
}
| LPAREN MULTIPLY token_or_expr_list RPAREN
{
 	Value* result  = Builder.getInt32(1);
	for(std::list<Value*>::iterator it=$3->begin(); it!= $3->end(); it++)
	{
		result = Builder.CreateMul(result, *it);
	}
	$$ = result;
}
| LPAREN DIVIDE token_or_expr_list RPAREN
{
	Value* int1 = Builder.getInt32(1);
	if($3->size() == 1)
	{
		std::list<Value*>::iterator it=$3->begin();
		$$ = *it;
		$$ = Builder.CreateSDiv($$, int1);
		$$ = Builder.CreateSDiv($$, int1);
	}
	else if($3->size() == 2)
	{
		std::list<Value*>::iterator it=$3->begin();
		$$ = *it;
		it++;
		$$ = Builder.CreateSDiv($$, *it);
		$$ = Builder.CreateSDiv($$, int1);
	}
	else
	{
		for(std::list<Value*>::iterator it=$3->begin(); it != $3->end();it++)
		{
			$$ = Builder.CreateSDiv($$, *it);
		}
	}
}
| LPAREN SETQ IDENT token_or_expr RPAREN
{
	Value* retVal = NULL;
	if (idLookup.find($3) == idLookup.end())
	{
		retVal = Builder.CreateAlloca(Builder.getInt32Ty(), nullptr, $3);
		idLookup[$3] = retVal;
	}
	else
	{
		retVal = idLookup[$3];
	}
  	$$ = Builder.CreateStore($4, retVal);
}
| LPAREN MIN token_or_expr_list RPAREN
{
	Value* int1;
	$$ = $3->front();
	for(std::list<Value*>::iterator it= $3->begin(); it != $3->end(); it++)
	{
		int1 = Builder.CreateICmpSLE($$, *it);
		$$ = Builder.CreateSelect(int1, $$, *it);
	}
}
| LPAREN MAX token_or_expr_list RPAREN
{	
	Value* int1;
	$$ = $3->front();
	for(std::list<Value*>::iterator it= $3->begin(); it != $3->end(); it++)
	{
		int1 = Builder.CreateICmpSGT($$, *it);
		$$ = Builder.CreateSelect(int1, $$, *it);
	}
}
| LPAREN SETF token_or_expr token_or_expr RPAREN
{
	LoadInst *inst = dyn_cast<LoadInst>($3);
	Value* addr = inst->getPointerOperand();
	$$ = Builder.CreateStore($4,addr);
}
| LPAREN AREF IDENT token_or_expr RPAREN
{
	Value* var = NULL;
	Value* int1 = Builder.CreateGEP(idLookup[$3], $4,"");
  	$$ = Builder.CreateLoad(int1) ;
}
| LPAREN MAKEARRAY IDENT NUM token_or_expr RPAREN
{
	Value* val = Builder.CreateAlloca(Builder.getInt32Ty(), Builder.getInt32($4), $3);
	idLookup[$3] = val;
	for(int i = 0; i < $4; i++)
	{
		Value* int1 = Builder.CreateGEP(idLookup[$3], Builder.getInt32(i),"");
		Builder.CreateStore($5, int1);
	}	
}
;

token_or_expr_list:   token_or_expr_list token_or_expr
{
    $$->push_back($2);
}
| token_or_expr
{
  	$$ = new std::list<Value*>;
    $$->push_back($1);
}
;

token_or_expr :  token
{
  $$ = $1;
}
| expr
{
   $$ = $1;
}
; 

token:   IDENT
{
  if (idLookup.find($1) != idLookup.end())
    $$ = Builder.CreateLoad(idLookup[$1]);
  else
    {
      YYABORT;      
      }
}
| NUM
{
	//create a val
  	Value* val = Builder.getInt32($1);
	$$ = val;
}
;

%%

void initialize()
{
  string s = "arg_array";
  idLookup[s] = (Value*)(Func->arg_begin()+1);
  string s2 = "arg_size";
  Argument *a = Func->arg_begin();
  Value * v = Builder.CreateAlloca(a->getType());
  Builder.CreateStore(a,v);
  idLookup[s2] = (Value*)v;
}

extern int line;

int yyerror(const char *msg)
{
  printf("%s at line %d.\n",msg,line);
  return 0;
}
