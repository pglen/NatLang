// NatLang
// -- A parser framework for natural language processing
// Copyright (Conj) 2011 Jerry Chen <mailto:onlyuser@gmail.com>
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.

//%output="NatLang.tab.c"
%name-prefix="_NATLANG_"

%{

#include "NatLang.h"
#include "node/XLangNodeIFace.h" // node::NodeIdentIFace
#include "NatLang.tab.h" // ID_XXX (yacc generated)
#include "XLangAlloc.h" // Allocator
#include "mvc/XLangMVCView.h" // mvc::MVCView
#include "mvc/XLangMVCModel.h" // mvc::MVCModel
#include "XLangTreeContext.h" // TreeContext
#include "XLangSystem.h" // xl::replace
#include "XLangString.h" // xl::replace
#include "XLangType.h" // uint32_t
#include "TryAllParses.h" // gen_variations
#include <stdio.h> // size_t
#include <stdarg.h> // va_start
#include <string.h> // strlen
#include <vector> // std::vector
#include <list> // std::list
#include <map> // std::map
#include <string> // std::string
#include <sstream> // std::stringstream
#include <iostream> // std::cout
#include <stdlib.h> // EXIT_SUCCESS
#include <getopt.h> // getopt_long

//#define DEBUG

#define MAKE_TERM(lexer_id, ...)   xl::mvc::MVCModel::make_term(&pc->tree_context(), lexer_id, ##__VA_ARGS__)
#define MAKE_SYMBOL(...)           xl::mvc::MVCModel::make_symbol(&pc->tree_context(), ##__VA_ARGS__)
#define ERROR_LEXER_ID_NOT_FOUND   "Missing lexer id handler. Did you forgot to register one?"
#define ERROR_LEXER_NAME_NOT_FOUND "Missing lexer name handler. Did you forgot to register one?"

// report error
void _nl(error)(YYLTYPE* loc, ParserContext* pc, yyscan_t scanner, const char* s)
{
    if(loc)
    {
        std::stringstream ss;
        int last_line_pos = 0;
        for(int i = pc->scanner_context().m_pos; i >= 0; i--)
        {
            if(pc->scanner_context().m_buf[i] == '\n')
            {
                last_line_pos = i+1;
                break;
            }
        }
        ss << &pc->scanner_context().m_buf[last_line_pos] << std::endl;
        ss << std::string(loc->first_column-1, '-') <<
                std::string(loc->last_column - loc->first_column + 1, '^') << std::endl <<
                loc->first_line << ":c" << loc->first_column << " to " <<
                loc->last_line << ":c" << loc->last_column << std::endl;
        error_messages() << ss.str();
    }
    error_messages() << s;
}
void _nl(error)(const char* s)
{
    _nl(error)(NULL, NULL, NULL, s);
}

// get resource
std::stringstream &error_messages()
{
    static std::stringstream _error_messages;
    return _error_messages;
}
void reset_error_messages()
{
    error_messages().str("");
    error_messages().clear();
}
std::string id_to_name(uint32_t lexer_id)
{
    static const char* _id_to_name[] = {
        "int",
        "float",
        "ident"
        };
    int index = static_cast<int>(lexer_id)-ID_BASE-1;
    if(index >= 0 && index < static_cast<int>(sizeof(_id_to_name)/sizeof(*_id_to_name)))
        return _id_to_name[index];
    switch(lexer_id)
    {
        case ID_ADJXXX:           return "AdjXXX";
        case ID_ADJ:              return "Adj";
        case ID_ADJX:             return "AdjX";
        case ID_ADJXX:            return "AdjXX";
        case ID_ADV_ADJ:          return "Adv_Adj";
        case ID_ADV_GERUND:       return "Adv_Gerund";
        case ID_ADV_PASTPART:     return "Adv_PastPart";
        case ID_ADV_PREP:         return "Adv_Prep";
        case ID_ADV:              return "Adv";
        case ID_ADV_V:            return "Adv_V";
        case ID_AUX_BE:           return "Aux_Be";
        case ID_AUX_DO:           return "Aux_Do";
        case ID_AUX_HAVE:         return "Aux_Have";
        case ID_COMMA_N:          return "Comma_N";
        case ID_COMMA_PREP:       return "Comma_Prep";
        case ID_COMMA_PREP2:      return "Comma_Prep2";
        case ID_COMMA_QWORD:      return "Comma_QWord";
        case ID_COMMA:            return "Comma";
        case ID_COMMA_V:          return "Comma_V";
        case ID_CONJ_ADJ:         return "Conj_Adj";
        case ID_CONJ_NP:          return "Conj_NP";
        case ID_CONJ:             return "Conj";
        case ID_CONJ_S:           return "Conj_S";
        case ID_CONJ_VP:          return "Conj_VP";
        case ID_DETSUFFIX:        return "DetSuffix";
        case ID_DETSUFFIXX:       return "DetSuffixX";
        case ID_DETX:             return "DetX";
        case ID_DET:              return "Det";
        case ID_EOS:              return "$";
        case ID_GERUNDXX:         return "GerundXX";
        case ID_GERUNDPX:         return "GerundX";
        case ID_GERUND:           return "Gerund";
        case ID_INFIN:            return "Infin";
        case ID_MODAL:            return "Modal";
        case ID_NP:               return "NP";
        case ID_NPX:              return "NPX";
        case ID_N:                return "N";
        case ID_NX:               return "NX";
        case ID_PASTPARTXX:       return "PastPartXX";
        case ID_PASTPARTX:        return "PastPartX";
        case ID_PASTPART:         return "PastPart";
        case ID_PREP_N:           return "Prep_N";
        case ID_PREPXX_N:         return "PrepXX_N";
        case ID_PREPX_N:          return "PrepX_N";
        case ID_PREPXX_S:         return "PrepXX_S";
        case ID_PREPX_S:          return "PrepX_S";
        case ID_PREP:             return "Prep";
        case ID_PREP_S:           return "Prep_S";
        case ID_QWORD_PRON:       return "QWord_Pron";
        case ID_S:                return "S";
        case ID_SX:               return "SX";
        case ID_TO:               return "To";
        case ID_VXX:              return "VXX";
        case ID_VX:               return "VX";
        case ID_VP:               return "VP";
        case ID_VPX:              return "VPX";
        case ID_V:                return "V";
    }
    throw ERROR_LEXER_ID_NOT_FOUND;
    return "";
}
uint32_t name_to_id(std::string name)
{
    if(name == "AdjXXX")           return ID_ADJXXX;
    if(name == "Adj")              return ID_ADJ;
    if(name == "AdjX")             return ID_ADJX;
    if(name == "AdjXX")            return ID_ADJXX;
    if(name == "Adv_Adj")          return ID_ADV_ADJ;
    if(name == "Adv_Gerund")       return ID_ADV_GERUND;
    if(name == "Adv_PastPart")     return ID_ADV_PASTPART;
    if(name == "Adv_Prep")         return ID_ADV_PREP;
    if(name == "Adv")              return ID_ADV;
    if(name == "Adv_V")            return ID_ADV_V;
    if(name == "Aux_Be")           return ID_AUX_BE;
    if(name == "Aux_Do")           return ID_AUX_DO;
    if(name == "Aux_Have")         return ID_AUX_HAVE;
    if(name == "Comma_N")          return ID_COMMA_N;
    if(name == "Comma_Prep")       return ID_COMMA_PREP;
    if(name == "Comma_Prep2")      return ID_COMMA_PREP2;
    if(name == "Comma_QWord")      return ID_COMMA_QWORD;
    if(name == "Comma")            return ID_COMMA;
    if(name == "Comma_V")          return ID_COMMA_V;
    if(name == "Conj_Adj")         return ID_CONJ_ADJ;
    if(name == "Conj_NP")          return ID_CONJ_NP;
    if(name == "Conj")             return ID_CONJ;
    if(name == "Conj_S")           return ID_CONJ_S;
    if(name == "Conj_VP")          return ID_CONJ_VP;
    if(name == "DetSuffix")        return ID_DETSUFFIX;
    if(name == "DetSuffixX")       return ID_DETSUFFIXX;
    if(name == "DetX")             return ID_DETX;
    if(name == "Det")              return ID_DET;
    if(name == "float")            return ID_FLOAT;
    if(name == "GerundXX")         return ID_GERUNDXX;
    if(name == "GerundX")          return ID_GERUNDPX;
    if(name == "Gerund")           return ID_GERUND;
    if(name == "ident")            return ID_IDENT;
    if(name == "Infin")            return ID_INFIN;
    if(name == "int")              return ID_INT;
    if(name == "Modal")            return ID_MODAL;
    if(name == "NP")               return ID_NP;
    if(name == "NPX")              return ID_NPX;
    if(name == "N")                return ID_N;
    if(name == "NX")               return ID_NX;
    if(name == "PastPartXX")       return ID_PASTPARTXX;
    if(name == "PastPartX")        return ID_PASTPARTX;
    if(name == "PastPart")         return ID_PASTPART;
    if(name == "Prep_N")           return ID_PREP_N;
    if(name == "PrepXX_N")         return ID_PREPXX_N;
    if(name == "PrepX_N")          return ID_PREPX_N;
    if(name == "PrepXX_S")         return ID_PREPXX_S;
    if(name == "PrepX_S")          return ID_PREPX_S;
    if(name == "Prep")             return ID_PREP;
    if(name == "Prep_S")           return ID_PREP_S;
    if(name == "QWord_Pron")       return ID_QWORD_PRON;
    if(name == "$")                return ID_EOS;
    if(name == "S")                return ID_S;
    if(name == "SX")               return ID_SX;
    if(name == "To")               return ID_TO;
    if(name == "VXX")              return ID_VXX;
    if(name == "VX")               return ID_VX;
    if(name == "VP")               return ID_VP;
    if(name == "VPX")              return ID_VPX;
    if(name == "V")                return ID_V;
    std::cout << name << std::endl;
    throw ERROR_LEXER_NAME_NOT_FOUND;
    return 0;
}

static void remap_pos_value_path_to_pos_lexer_id_path(
        const std::vector<std::string> &pos_value_path,    // IN
        std::vector<uint32_t>*          pos_lexer_id_path) // OUT
{
    if(!pos_lexer_id_path)
        return;
    for(auto p = pos_value_path.begin(); p != pos_value_path.end(); p++)
        pos_lexer_id_path->push_back(name_to_id(*p));
}

static std::string expand_contractions(std::string &sentence)
{
    std::string s = sentence;
    s = xl::replace(s, "n't", " not");
    s = xl::replace(s, "'ve", " have");
    s = xl::replace(s, "'m", " am");
    s = xl::replace(s, "'re", " are");
    s = xl::replace(s, "'s", " 's");
    s = xl::replace(s, ",", " , ");
    return s;
}

static bool filter_singleton(const xl::node::NodeIdentIFace* _node)
{
    if(_node->type() != xl::node::NodeIdentIFace::SYMBOL || _node->height() <= 1)
        return false;
    auto symbol = dynamic_cast<const xl::node::SymbolNodeIFace*>(_node);
    return symbol->size() == 1;
}

%}

// 'pure_parser' tells bison to use no global variables and create a
// reentrant parser (NOTE: deprecated, use "%define api.pure" instead).
%define api.pure
%parse-param {ParserContext* pc}
%parse-param {yyscan_t scanner}
%lex-param {scanner}

// show detailed parse errors
%error-verbose

// record where each token occurs in input
%locations

%nonassoc ID_BASE

%token<int_value>   ID_INT
%token<float_value> ID_FLOAT
%token<ident_value> ID_IDENT

//=============================================================================
// non-terminal lvalues
//=============================================================================

// high-level constructs
%type<symbol_value> S NP VP

// local constructs
%type<symbol_value> Infin VX GerundX GerundXX PastPartX VXX PastPartXX AdjXXX NX AdjX

// lists
%type<symbol_value> SX NPX VPX AdjXX PrepX_N PrepXX_N PrepX_S PrepXX_S DetX DetSuffixX

//=============================================================================
// non-terminal lvalue lexer IDs
//=============================================================================

// high-level constructs
%nonassoc ID_S ID_NP ID_VP

// local constructs
%nonassoc ID_INFIN ID_VX ID_GERUNDPX ID_GERUNDXX ID_PASTPARTX ID_VXX ID_PASTPARTXX ID_ADJXXX ID_NX ID_ADJX

// lists
%nonassoc ID_SX ID_NPX ID_VPX ID_ADJXX ID_PREPX_N ID_PREPXX_N ID_PREPX_S ID_PREPXX_S ID_DETX ID_DETSUFFIXX

//=============================================================================
// terminal lvalues
//=============================================================================

// descriptive words
%type<symbol_value> N V PastPart Gerund Adj
%type<symbol_value> Prep_N Prep_S

// functional words
%type<symbol_value> Det DetSuffix Aux_Be Aux_Do Aux_Have Modal To QWord_Pron EOS
%type<symbol_value> Comma_Prep Comma_Prep2 Comma_N Comma_QWord Comma_V

// ambiguous terminals
%type<symbol_value> Conj_S Conj_NP Conj_VP Conj_Adj
%type<symbol_value> Adv_V Adv_Gerund Adv_PastPart Adv_Prep Adv_Adj

//=============================================================================
// terminal rvalues
//=============================================================================

// descriptive words
%token<ident_value> ID_N ID_V ID_PASTPART ID_GERUND ID_ADJ
%token<ident_value> ID_PREP
%token<ident_value> ID_PREP_N ID_PREP_S

// functional words
%token<ident_value> ID_DET ID_DETSUFFIX ID_AUX_BE ID_AUX_DO ID_AUX_HAVE ID_MODAL ID_TO ID_QWORD_PRON ID_EOS
%token<ident_value> ID_COMMA
%token<ident_value> ID_COMMA_PREP ID_COMMA_PREP2 ID_COMMA_N ID_COMMA_QWORD ID_COMMA_V

// ambiguous terminals
%token<ident_value> ID_CONJ
%token<ident_value> ID_CONJ_S ID_CONJ_NP ID_CONJ_VP ID_CONJ_ADJ
%token<ident_value> ID_ADV
%token<ident_value> ID_ADV_V ID_ADV_GERUND ID_ADV_PASTPART ID_ADV_PREP ID_ADV_ADJ

%%

//=============================================================================
// NON-TERMINALS
//=============================================================================
// high-level constructs

root:
      SX EOS { pc->tree_context().root() = $1; YYACCEPT; }
    | error  { yyclearin; /* yyerrok; YYABORT; */ }
    ;

S:
      NPX VPX                     { $$ = MAKE_SYMBOL(ID_S, @$, 2, $1, $2); }         // he goes
    | PrepXX_S Comma_Prep NPX VPX { $$ = MAKE_SYMBOL(ID_S, @$, 4, $1, $2, $3, $4); } // from here, he goes
    ;

NP:
      NX                                          { $$ = MAKE_SYMBOL(ID_NP, @$, 1, $1); }                     // john
    | DetX                                        { $$ = MAKE_SYMBOL(ID_NP, @$, 1, $1); }                     // the teacher
    | NX Comma_N DetX Comma_N                     { $$ = MAKE_SYMBOL(ID_NP, @$, 4, $1, $2, $3, $4); }         // john, the teacher,
    | DetX Comma_N NX                             { $$ = MAKE_SYMBOL(ID_NP, @$, 3, $1, $2, $3); }             // the teacher, john
    | NX Comma_N GerundXX Comma_V                 { $$ = MAKE_SYMBOL(ID_NP, @$, 3, $1, $2, $3); }             // john, reading a book,
    | GerundXX Comma_V NX                         { $$ = MAKE_SYMBOL(ID_NP, @$, 3, $1, $2, $3); }             // reading a book, john
    | NP PrepX_N                                  { $$ = MAKE_SYMBOL(ID_NP, @$, 2, $1, $2); }                 // john from work
    | NP Comma_Prep2 PrepX_N Comma_Prep           { $$ = MAKE_SYMBOL(ID_NP, @$, 4, $1, $2, $3, $4); }         // john, from work,
    | NP Comma_QWord QWord_Pron VP Comma_QWord    { $$ = MAKE_SYMBOL(ID_NP, @$, 5, $1, $2, $3, $4, $5); }     // john, who is here,
    | NP Comma_QWord QWord_Pron NP VP Comma_QWord { $$ = MAKE_SYMBOL(ID_NP, @$, 6, $1, $2, $3, $4, $5, $6); } // john, who we know,
    | Infin                                       { $$ = MAKE_SYMBOL(ID_NP, @$, 1, $1); }                     // to bring it
    | GerundXX                                    { $$ = MAKE_SYMBOL(ID_NP, @$, 1, $1); }                     // bringing it
    ;

VP:
      VXX                 { $$ = MAKE_SYMBOL(ID_VP, @$, 1, $1); }     // bring it
    | Aux_Be GerundXX     { $$ = MAKE_SYMBOL(ID_VP, @$, 2, $1, $2); } // is bringing it
    | Aux_Do VXX          { $$ = MAKE_SYMBOL(ID_VP, @$, 2, $1, $2); } // do bring it
    | Aux_Have PastPartXX { $$ = MAKE_SYMBOL(ID_VP, @$, 2, $1, $2); } // has brought it
    | Modal VP            { $$ = MAKE_SYMBOL(ID_VP, @$, 2, $1, $2); } // could bring it
    ;

//=============================================================================
// local constructs

Infin:
      To VXX { $$ = MAKE_SYMBOL(ID_INFIN, @$, 2, $1, $2); } // to give
    ;

VXX:
      VX       { $$ = MAKE_SYMBOL(ID_VXX, @$, 1, $1); }     // bring it
    | Adv_V VX { $$ = MAKE_SYMBOL(ID_VXX, @$, 2, $1, $2); } // quickly bring it
    | VX Adv_V { $$ = MAKE_SYMBOL(ID_VXX, @$, 2, $1, $2); } // bring it quickly

GerundXX:
      GerundX            { $$ = MAKE_SYMBOL(ID_GERUNDXX, @$, 1, $1); }     // bringing it
    | Adv_Gerund GerundX { $$ = MAKE_SYMBOL(ID_GERUNDXX, @$, 2, $1, $2); } // quickly bringing it
    | GerundX Adv_Gerund { $$ = MAKE_SYMBOL(ID_GERUNDXX, @$, 2, $1, $2); } // bringing it quickly

PastPartXX:
      PastPartX              { $$ = MAKE_SYMBOL(ID_PASTPARTXX, @$, 1, $1); }     // brought it
    | Adv_PastPart PastPartX { $$ = MAKE_SYMBOL(ID_PASTPARTXX, @$, 2, $1, $2); } // quickly brought it
    | PastPartX Adv_PastPart { $$ = MAKE_SYMBOL(ID_PASTPARTXX, @$, 2, $1, $2); } // brought it quickly

VX:
      V             { $$ = MAKE_SYMBOL(ID_VX, @$, 1, $1); }         // bring
    | V NPX         { $$ = MAKE_SYMBOL(ID_VX, @$, 2, $1, $2); }     // bring it
    | V NPX NPX     { $$ = MAKE_SYMBOL(ID_VX, @$, 3, $1, $2, $3); } // bring me it
    | V NPX PrepX_N { $$ = MAKE_SYMBOL(ID_VX, @$, 3, $1, $2, $3); } // bring it to me
    | V AdjXXX      { $$ = MAKE_SYMBOL(ID_VX, @$, 2, $1, $2); }     // be mad about you
    | V PrepXX_N    { $$ = MAKE_SYMBOL(ID_VX, @$, 2, $1, $2); }     // beat around the bush
    | V AdjXX       { $$ = MAKE_SYMBOL(ID_VX, @$, 2, $1, $2); }     // be happy
    ;

GerundX:
      Gerund             { $$ = MAKE_SYMBOL(ID_GERUNDPX, @$, 1, $1); }         // bringing
    | Gerund NPX         { $$ = MAKE_SYMBOL(ID_GERUNDPX, @$, 2, $1, $2); }     // bringing it
    | Gerund NPX NPX     { $$ = MAKE_SYMBOL(ID_GERUNDPX, @$, 3, $1, $2, $3); } // bringing me it
    | Gerund NPX PrepX_N { $$ = MAKE_SYMBOL(ID_GERUNDPX, @$, 3, $1, $2, $3); } // bringing it to me
    | Gerund AdjXXX      { $$ = MAKE_SYMBOL(ID_GERUNDPX, @$, 2, $1, $2); }     // being mad about you
    | Gerund PrepXX_N    { $$ = MAKE_SYMBOL(ID_GERUNDPX, @$, 2, $1, $2); }     // beating around the bush
    | Gerund AdjXX       { $$ = MAKE_SYMBOL(ID_GERUNDPX, @$, 2, $1, $2); }     // being happy
    ;

PastPartX:
      PastPart             { $$ = MAKE_SYMBOL(ID_PASTPARTX, @$, 1, $1); }         // brought
    | PastPart NPX         { $$ = MAKE_SYMBOL(ID_PASTPARTX, @$, 2, $1, $2); }     // brought it
    | PastPart NPX NPX     { $$ = MAKE_SYMBOL(ID_PASTPARTX, @$, 3, $1, $2, $3); } // brought me it
    | PastPart NPX PrepX_N { $$ = MAKE_SYMBOL(ID_PASTPARTX, @$, 3, $1, $2, $3); } // brought it to me
    | PastPart AdjXXX      { $$ = MAKE_SYMBOL(ID_PASTPARTX, @$, 2, $1, $2); }     // been mad about you
    | PastPart PrepXX_N    { $$ = MAKE_SYMBOL(ID_PASTPARTX, @$, 2, $1, $2); }     // beaten around the bush
    | PastPart AdjXX       { $$ = MAKE_SYMBOL(ID_PASTPARTX, @$, 2, $1, $2); }     // been happy
    ;

AdjXXX:
      AdjXX PrepX_N { $$ = MAKE_SYMBOL(ID_ADJXXX, @$, 2, $1, $2); } // mad about you
    ;

NX:
      N       { $$ = MAKE_SYMBOL(ID_NX, @$, 1, $1); }     // dog
    | AdjXX N { $$ = MAKE_SYMBOL(ID_NX, @$, 2, $1, $2); } // big and red dog
    ;

AdjX:
      Adj         { $$ = MAKE_SYMBOL(ID_ADJX, @$, 1, $1); }     // red
    | Adv_Adj Adj { $$ = MAKE_SYMBOL(ID_ADJX, @$, 2, $1, $2); } // very red
    ;

//=============================================================================
// lists

SX:
      S            { $$ = MAKE_SYMBOL(ID_SX, @$, 1, $1); }         // i jump
    | SX Conj_S SX { $$ = MAKE_SYMBOL(ID_SX, @$, 3, $1, $2, $3); } // i jump and you jump
    ;

NPX:
      NP              { $$ = MAKE_SYMBOL(ID_NPX, @$, 1, $1); }         // jack
    | NPX Conj_NP NPX { $$ = MAKE_SYMBOL(ID_NPX, @$, 3, $1, $2, $3); } // jack and jill
    ;

VPX:
      VP              { $$ = MAKE_SYMBOL(ID_VPX, @$, 1, $1); }         // hit
    | VPX Conj_VP VPX { $$ = MAKE_SYMBOL(ID_VPX, @$, 3, $1, $2, $3); } // hit and run
    ;

AdjXX:
      AdjX                 { $$ = MAKE_SYMBOL(ID_ADJXX, @$, 1, $1); }         // big
    | AdjXX AdjXX          { $$ = MAKE_SYMBOL(ID_ADJXX, @$, 2, $1, $2); }     // big red
    | AdjXX Conj_Adj AdjXX { $$ = MAKE_SYMBOL(ID_ADJXX, @$, 3, $1, $2, $3); } // big and red
    ;

PrepXX_N:
      PrepX_N          { $$ = MAKE_SYMBOL(ID_PREPXX_N, @$, 1, $1); }     // from here
    | Adv_Prep PrepX_N { $$ = MAKE_SYMBOL(ID_PREPXX_N, @$, 2, $1, $2); } // not from here
    ;

PrepXX_S:
      PrepX_S          { $$ = MAKE_SYMBOL(ID_PREPXX_S, @$, 1, $1); }     // from here
    | Adv_Prep PrepX_S { $$ = MAKE_SYMBOL(ID_PREPXX_S, @$, 2, $1, $2); } // not from here
    ;

PrepX_N:
      Prep_N NPX      { $$ = MAKE_SYMBOL(ID_PREPX_N, @$, 2, $1, $2); } // around the corner
    | PrepX_N PrepX_N { $$ = MAKE_SYMBOL(ID_PREPX_N, @$, 2, $1, $2); } // around the corner across the street
    ;

PrepX_S:
      Prep_S NPX      { $$ = MAKE_SYMBOL(ID_PREPX_S, @$, 2, $1, $2); } // around the corner
    | PrepX_S PrepX_S { $$ = MAKE_SYMBOL(ID_PREPX_S, @$, 2, $1, $2); } // around the corner across the street
    ;

DetX:
      Det NX            { $$ = MAKE_SYMBOL(ID_DETX, @$, 2, $1, $2); }     // the man
    | Det NX DetSuffixX { $$ = MAKE_SYMBOL(ID_DETX, @$, 3, $1, $2, $3); } // the man's wife
    | NX DetSuffixX     { $$ = MAKE_SYMBOL(ID_DETX, @$, 2, $1, $2); }     // john's wife
    ;

DetSuffixX:
      DetSuffix NX            { $$ = MAKE_SYMBOL(ID_DETSUFFIXX, @$, 2, $1, $2); }     // 's wife
    | DetSuffix NX DetSuffixX { $$ = MAKE_SYMBOL(ID_DETSUFFIXX, @$, 3, $1, $2, $3); } // 's wife's sister
    ;

//=============================================================================
// TERMINALS
//=============================================================================
// descriptive words

N:
      ID_N { $$ = MAKE_SYMBOL(ID_N, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // dog
    ;

V:
      ID_V { $$ = MAKE_SYMBOL(ID_V, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // run
    ;

Gerund:
      ID_GERUND { $$ = MAKE_SYMBOL(ID_GERUND, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // running
    ;

PastPart:
      ID_PASTPART { $$ = MAKE_SYMBOL(ID_PASTPART, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // run
    ;

Adj:
      ID_ADJ { $$ = MAKE_SYMBOL(ID_ADJ, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // big
    ;

Prep_N:
      ID_PREP_N { $$ = MAKE_SYMBOL(ID_PREP_N, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Prep_S:
      ID_PREP_S { $$ = MAKE_SYMBOL(ID_PREP_S, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

//=============================================================================
// functional words

Det:
      ID_DET { $$ = MAKE_SYMBOL(ID_DET, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // the
    ;

DetSuffix:
      ID_DETSUFFIX { $$ = MAKE_SYMBOL(ID_DETSUFFIX, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // 's
    ;

Aux_Be:
      ID_AUX_BE { $$ = MAKE_SYMBOL(ID_AUX_BE, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Aux_Do:
      ID_AUX_DO { $$ = MAKE_SYMBOL(ID_AUX_DO, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Aux_Have:
      ID_AUX_HAVE { $$ = MAKE_SYMBOL(ID_AUX_HAVE, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Modal:
      ID_MODAL { $$ = MAKE_SYMBOL(ID_MODAL, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // could
    ;

To:
      ID_TO { $$ = MAKE_SYMBOL(ID_TO, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // to
    ;

QWord_Pron:
      ID_QWORD_PRON { $$ = MAKE_SYMBOL(ID_QWORD_PRON, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // who/which/that
    ;

EOS:
      ID_EOS { $$ = MAKE_SYMBOL(ID_EOS, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

//=============================================================================
// ambiguous terminals

Conj_S:
      ID_CONJ_S { $$ = MAKE_SYMBOL(ID_CONJ_S, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // and (for S)
    ;

Conj_NP:
      ID_CONJ_NP { $$ = MAKE_SYMBOL(ID_CONJ_NP, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // and (for NP)
    ;

Conj_VP:
      ID_CONJ_VP { $$ = MAKE_SYMBOL(ID_CONJ_VP, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // and (for VP)
    ;

Conj_Adj:
      ID_CONJ_ADJ { $$ = MAKE_SYMBOL(ID_CONJ_ADJ, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); } // and (for AdjX)
    ;

Adv_V:
      ID_ADV_V { $$ = MAKE_SYMBOL(ID_ADV_V, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Adv_Gerund:
      ID_ADV_GERUND { $$ = MAKE_SYMBOL(ID_ADV_GERUND, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Adv_PastPart:
      ID_ADV_PASTPART { $$ = MAKE_SYMBOL(ID_ADV_PASTPART, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Adv_Adj:
      ID_ADV_ADJ { $$ = MAKE_SYMBOL(ID_ADV_ADJ, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Adv_Prep:
      ID_ADV_PREP { $$ = MAKE_SYMBOL(ID_ADV_PREP, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Comma_Prep:
      ID_COMMA_PREP { $$ = MAKE_SYMBOL(ID_COMMA_PREP, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Comma_Prep2:
      ID_COMMA_PREP2 { $$ = MAKE_SYMBOL(ID_COMMA_PREP2, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Comma_N:
      ID_COMMA_N { $$ = MAKE_SYMBOL(ID_COMMA_N, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Comma_QWord:
      ID_COMMA_QWORD { $$ = MAKE_SYMBOL(ID_COMMA_QWORD, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Comma_V:
      ID_COMMA_V { $$ = MAKE_SYMBOL(ID_COMMA_V, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

//=============================================================================

%%

ScannerContext::ScannerContext(const char* buf)
    : m_scanner(NULL), m_buf(buf), m_pos(0), m_length(strlen(buf)),
      m_line(1), m_column(1), m_prev_column(1), m_word_index(0),
      m_pos_lexer_id_path(NULL)
{}

uint32_t ScannerContext::current_lexer_id()
{
    if(!m_pos_lexer_id_path)
    {
        throw ERROR_LEXER_ID_NOT_FOUND;
        return 0;
    }
    return (*m_pos_lexer_id_path)[m_word_index];
}

uint32_t quick_lex(const char* s)
{
    xl::Allocator alloc(__FILE__);
    ParserContext parser_context(alloc, s);
    yyscan_t scanner = parser_context.scanner_context().m_scanner;
    _nl(lex_init)(&scanner);
    _nl(set_extra)(&parser_context, scanner);
    YYSTYPE dummy_sa;
    YYLTYPE dummy_loc;
    uint32_t lexer_id = _nl(lex)(&dummy_sa, &dummy_loc, scanner); // scanner entry point
    _nl(lex_destroy)(scanner);
    return lexer_id;
}

xl::node::NodeIdentIFace* make_ast(
        xl::Allocator         &alloc,
        const char*            s,
        std::vector<uint32_t> &pos_lexer_id_path)
{
    ParserContext parser_context(alloc, s);
    parser_context.scanner_context().m_pos_lexer_id_path = &pos_lexer_id_path;
    yyscan_t scanner = parser_context.scanner_context().m_scanner;
    _nl(lex_init)(&scanner);
    _nl(set_extra)(&parser_context, scanner);
    int error_code = _nl(parse)(&parser_context, scanner); // parser entry point
    _nl(lex_destroy)(scanner);
    return (!error_code && error_messages().str().empty()) ? parser_context.tree_context().root() : NULL;
}

void display_usage(bool verbose)
{
    std::cout << "Usage: NatLang [-i] OPTION [-m]" << std::endl;
    if(verbose)
    {
        std::cout << "Parses input and prints a syntax tree to standard out" << std::endl
                << std::endl
                << "Input control:" << std::endl
                << "  -i, --in-xml FILENAME (de-serialize from xml)" << std::endl
                << "  -e, --expr EXPRESSION" << std::endl
                << std::endl
                << "Output control:" << std::endl
                << "  -l, --lisp" << std::endl
                << "  -x, --xml" << std::endl
                << "  -g, --graph" << std::endl
                << "  -d, --dot" << std::endl
                << "  -s, --skip_singleton" << std::endl
                << "  -m, --memory" << std::endl
                << "  -h, --help" << std::endl;
    }
    else
        std::cout << "Try `NatLang --help\' for more information." << std::endl;
}

struct options_t
{
    typedef enum
    {
        MODE_NONE,
        MODE_LISP,
        MODE_XML,
        MODE_GRAPH,
        MODE_DOT,
        MODE_HELP
    } mode_e;

    mode_e      mode;
    std::string in_xml;
    std::string expr;
    bool        dump_memory;
    bool        skip_singleton;

    options_t()
        : mode(MODE_NONE), dump_memory(false), skip_singleton(false)
    {}
};

bool extract_options_from_args(options_t* options, int argc, char** argv)
{
    if(!options)
        return false;
    int opt = 0;
    int longIndex = 0;
    static const char *optString = "i:e:lxgdsmh?";
    static const struct option longOpts[] = {
                { "in-xml",         required_argument, NULL, 'i' },
                { "expr",           required_argument, NULL, 'e' },
                { "lisp",           no_argument,       NULL, 'l' },
                { "xml",            no_argument,       NULL, 'x' },
                { "graph",          no_argument,       NULL, 'g' },
                { "dot",            no_argument,       NULL, 'd' },
                { "skip_singleton", no_argument,       NULL, 's' },
                { "memory",         no_argument,       NULL, 'm' },
                { "help",           no_argument,       NULL, 'h' },
                { NULL,             no_argument,       NULL, 0 }
            };
    opt = getopt_long(argc, argv, optString, longOpts, &longIndex);
    while(opt != -1)
    {
        switch(opt)
        {
            case 'i': options->in_xml = optarg; break;
            case 'e': options->expr = optarg; break;
            case 'l': options->mode = options_t::MODE_LISP; break;
            case 'x': options->mode = options_t::MODE_XML; break;
            case 'g': options->mode = options_t::MODE_GRAPH; break;
            case 'd': options->mode = options_t::MODE_DOT; break;
            case 's': options->skip_singleton = true; break;
            case 'm': options->dump_memory = true; break;
            case 'h':
            case '?': options->mode = options_t::MODE_HELP; break;
            case 0: // reserved
            default:
                break;
        }
        opt = getopt_long(argc, argv, optString, longOpts, &longIndex);
    }
    return options->mode != options_t::MODE_NONE || options->dump_memory;
}

struct pos_value_path_ast_tuple_t
{
    std::vector<std::string>  m_pos_value_path;
    xl::node::NodeIdentIFace* m_ast;
    int                       m_path_index;

    pos_value_path_ast_tuple_t(
            std::vector<std::string>  &pos_value_path,
            xl::node::NodeIdentIFace*  ast,
            int                        path_index)
        : m_pos_value_path(pos_value_path),
          m_ast(ast),
          m_path_index(path_index) {}
};

bool import_ast(
        options_t                   &options,
        xl::Allocator               &alloc,
        pos_value_path_ast_tuple_t*  pos_value_path_ast_tuple)
{
    if(!pos_value_path_ast_tuple)
        return false;
    if(options.in_xml.size())
    {
        #if 0 // NOTE: not supported
            xl::node::NodeIdentIFace* _ast = xl::mvc::MVCModel::make_ast(
                    new (PNEW(alloc, xl::, TreeContext)) xl::TreeContext(alloc),
                    options.in_xml);
            if(!_ast)
            {
                std::cerr << "ERROR: de-serialize from xml fail!" << std::endl;
                return false;
            }
            pos_value_path_ast_tuple->m_ast = _ast;
        #endif
    }
    else
    {
        std::vector<std::string> &pos_value_path = pos_value_path_ast_tuple->m_pos_value_path;
        std::string pos_value_path_str;
        for(auto p = pos_value_path.begin(); p != pos_value_path.end(); p++)
            pos_value_path_str.append(*p + " ");
        #ifdef DEBUG
            std::cerr << "INFO: import path #" <<
                    pos_value_path_ast_tuple->m_path_index <<
                    ": <" << pos_value_path_str << ">" << std::endl;
        #endif
        std::vector<uint32_t> pos_lexer_id_path;
        remap_pos_value_path_to_pos_lexer_id_path(pos_value_path, &pos_lexer_id_path);
        xl::node::NodeIdentIFace* _ast =
                make_ast(alloc, options.expr.c_str(), pos_lexer_id_path);
        if(!_ast)
        {
            #ifdef DEBUG
                std::cerr << "ERROR: " << error_messages().str().c_str() << std::endl;
            #endif
            reset_error_messages();
            pos_value_path_ast_tuple->m_ast = NULL;
            return false;
        }
        xl::mvc::MVCView::annotate_tree(_ast);
        pos_value_path_ast_tuple->m_ast = _ast;
    }
    return true;
}

void export_ast(
        options_t                  &options,
        pos_value_path_ast_tuple_t &pos_value_path_ast_tuple)
{
    xl::node::NodeIdentIFace* ast = pos_value_path_ast_tuple.m_ast;
    if(!ast)
        return;
    std::vector<std::string> &pos_value_path = pos_value_path_ast_tuple.m_pos_value_path;
    std::string pos_value_path_str;
    for(auto p = pos_value_path.begin(); p != pos_value_path.end(); p++)
        pos_value_path_str.append(*p + " ");
    std::cerr << "INFO: export path #" <<
            pos_value_path_ast_tuple.m_path_index <<
            ": <" << pos_value_path_str << ">" << std::endl;
    xl::visitor::Filterable::filter_cb_t filter_cb = NULL;
    if(options.skip_singleton)
    {
        filter_cb = filter_singleton;
        if(options.mode == options_t::MODE_GRAPH || options.mode == options_t::MODE_DOT)
        {
            std::cerr << "ERROR: \"skip_singleton\" not supported for this mode!" << std::endl;
            return;
        }
    }
    switch(options.mode)
    {
        case options_t::MODE_LISP:  xl::mvc::MVCView::print_lisp(ast, filter_cb); break;
        case options_t::MODE_XML:   xl::mvc::MVCView::print_xml(ast, filter_cb); break;
        case options_t::MODE_GRAPH: xl::mvc::MVCView::print_graph(ast); break;
        case options_t::MODE_DOT:   xl::mvc::MVCView::print_dot(ast, false, false); break;
        default:
            break;
    }
}

bool apply_options(options_t &options)
{
    if(options.mode == options_t::MODE_HELP)
    {
        display_usage(true);
        return true;
    }
    xl::Allocator alloc(__FILE__);
    if(options.expr.empty() || options.in_xml.size())
    {
        std::cerr << "ERROR: mode not supported!" << std::endl;
        if(options.dump_memory)
            alloc.dump(std::string(1, '\t'));
        return false;
    }
    std::list<std::vector<std::string>> pos_value_paths;
    std::string sentence = options.expr;
    options.expr = sentence = expand_contractions(sentence);
    build_pos_value_paths_from_sentence(&pos_value_paths, sentence);
    int path_index = 0;
    std::list<pos_value_path_ast_tuple_t> pos_value_path_ast_tuples;
    for(auto p = pos_value_paths.begin(); p != pos_value_paths.end(); p++)
    {
        pos_value_path_ast_tuples.push_back(pos_value_path_ast_tuple_t(*p, NULL, path_index));
        path_index++;
    }
    for(auto q = pos_value_path_ast_tuples.begin(); q != pos_value_path_ast_tuples.end(); q++)
    {
        try
        {
            if(!import_ast(options, alloc, &(*q)))
                continue;
        }
        catch(const char* s)
        {
            std::cerr << "ERROR: " << s << std::endl;
            continue;
        }
    }
    if(options.mode == options_t::MODE_DOT)
    {
        xl::mvc::MVCView::print_dot_header(false);
        for(auto r = pos_value_path_ast_tuples.begin(); r != pos_value_path_ast_tuples.end(); r++)
            export_ast(options, *r);
        xl::mvc::MVCView::print_dot_footer();
    }
    else
    {
        for(auto r = pos_value_path_ast_tuples.begin(); r != pos_value_path_ast_tuples.end(); r++)
            export_ast(options, *r);
    }
    if(options.dump_memory)
        alloc.dump(std::string(1, '\t'));
    return true;
}

void add_signal_handlers()
{
    xl::system::add_sighandler(SIGABRT, xl::system::backtrace_sighandler);
    xl::system::add_sighandler(SIGINT,  xl::system::backtrace_sighandler);
    xl::system::add_sighandler(SIGSEGV, xl::system::backtrace_sighandler);
    xl::system::add_sighandler(SIGFPE,  xl::system::backtrace_sighandler);
    xl::system::add_sighandler(SIGBUS,  xl::system::backtrace_sighandler);
    xl::system::add_sighandler(SIGILL,  xl::system::backtrace_sighandler);
}

int main(int argc, char** argv)
{
    add_signal_handlers();
    options_t options;
    if(!extract_options_from_args(&options, argc, argv))
    {
        display_usage(false);
        return EXIT_FAILURE;
    }
    options.expr.append(" .");
    if(!apply_options(options))
        return EXIT_FAILURE;
    return EXIT_SUCCESS;
}
