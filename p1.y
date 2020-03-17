%{
#include <stdio.h>
#include <iostream>
#include <string.h>
#include <errno.h>
#include <list>
#include <map>
  
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
%type <val> expr program
%type <val> exprlist token token_or_expr 
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
  Builder.CreateRet(Builder.getInt32(0));
  return 0;
}
;

exprlist:  exprlist expr 
{
	$$ = $2;
}
| expr 
{
	$$ = $1;
}
;

expr: LPAREN MINUS token_or_expr_list RPAREN
{ 
	for(std::list<Value*>::iterator it=$3->begin(); it!= $3->end(); it++)
	{
		if($3->begin() != $3->end())
		{
			std::cout << "syntax error for MINUS";
			YYABORT;
		}
		else
		{
			$$ = Builder.CreateNeg(*it);
		}
	}
}
| LPAREN PLUS token_or_expr_list RPAREN
{
	//$$ =0;
	for(std::list<Value*>::iterator it=$3->begin(); it!= $3->end(); it++)
	{
		cout << *it << endl;
		$$ = Builder.CreateAdd($$, *it);
	}
}
| LPAREN MULTIPLY token_or_expr_list RPAREN
{
	Value* int1 = Builder.getInt32(1);
  	$$ = int1 ;
	for(std::list<Value*>::iterator it=$3->begin(); it!= $3->end(); it++)
	{
		
		$$ = Builder.CreateMul($$, *it);
	}
}
| LPAREN DIVIDE token_or_expr_list RPAREN
{
	Value* int1 = Builder.getInt32(1);
  	$$ = int1 ;
	if($3->size() == 1)
	{
		std::list<Value*>::iterator it=$3->begin();
		$$ = (*it);
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
	Value* val = NULL;
	if (idLookup.find($3) == idLookup.end())
	{
		val = Builder.CreateAlloca(Builder.getInt32Ty(), nullptr, $3);
		idLookup[$3] = val;
	}
	else
	{
		val = idLookup[$3];
	}
  	$$ = Builder.CreateStore($4, val);
}
| LPAREN MIN token_or_expr_list RPAREN
{
	std::list<Value*>::iterator it= $3->begin();
	Value *val1 = *it;
	advance(it,1);
	Value *val2 = *it;
	Value* val3  = Builder.getInt32(0);
	while(it != $3->end())
	{
		Value* int1 = Builder.CreateICmpSLE(val1, val2);
		val3 = Builder.CreateSelect(int1, val1, val2);
		it++;
	}
	$$ = val3;
}
| LPAREN MAX token_or_expr_list RPAREN
{
	std::list<Value*>::iterator it = $3->begin();
	Value* val1 = *it;
	advance(it,1);
	Value* val2 = *it;
	Value* val3  = Builder.getInt32(0);
	while(it != $3->end())
	{
		Value* int1 = Builder.CreateICmpSGT(val1, val2);
		Value* val3 = Builder.CreateSelect(int1, val2, val1);
		it++;
	}
	$$ = val3; 
}
| LPAREN SETF token_or_expr token_or_expr RPAREN
{
  // ECE 566 only
	$$ = Builder.CreateStore($4,$3);	
}
| LPAREN AREF IDENT token_or_expr RPAREN
{
	//std::list<Value*>::iterator it = $3->begin();
	Value* var = NULL;
	Value* int1 = Builder.CreateGEP(idLookup[$3], $4,"arg_array");
  	$$ = Builder.CreateLoad(int1) ;
}
| LPAREN MAKEARRAY IDENT NUM token_or_expr RPAREN
{
  // ECE 566 only
	//https://iss.oden.utexas.edu/projects/galois/api/2.2/classllvm_1_1ArrayRef.html
}
;

token_or_expr_list:   token_or_expr_list token_or_expr
{
  $$->push_back($2);
}
| token_or_expr
{
   //IMPLEMENT
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
  // IMPLEMENT
  $$ = $1;
}
; 

token:   IDENT
{
	if (idLookup.find($1) != idLookup.end())
	{
		$$ = Builder.CreateLoad(idLookup[$1]);
	}
	else
	{
		YYABORT;      
	}
	
}
| NUM
{
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
  
  /* IMPLEMENT: add something else here if needed */
}

extern int line;

int yyerror(const char *msg)
{
  printf("%s at line %d.\n",msg,line);
  return 0;
}
