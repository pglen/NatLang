// NatLang
// -- A parser framework for natural language processing
// Copyright (C) 2011 Jerry Chen <mailto:onlyuser@gmail.com>
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
#define ERROR_LEXER_ID_NOT_FOUND   "missing lexer id handler, most likely you forgot to register one"
#define ERROR_LEXER_NAME_NOT_FOUND "missing lexer name handler, most likely you forgot to register one"

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
        case ID_CS:     return "S'";
        case ID_S:      return "S";
        case ID_NP:     return "NP";
        case ID_VP:     return "VP";
        case ID_AP:     return "AP";
        case ID_PP:     return "PP";
        case ID_N:      return "N";
        case ID_V:      return "V";
        case ID_CA:     return "A'";
        case ID_A:      return "A";
        case ID_NOUN:   return "Noun";
        case ID_VERB:   return "Verb";
        case ID_ADJ:    return "Adj";
        case ID_ADV:    return "Adv";
        case ID_MODAL:  return "Modal";
        case ID_PREP:   return "Prep";
        case ID_AUX:    return "Aux";
        case ID_DET:    return "Det";
        case ID_CONJ:   return "Conj";
        case ID_CONJ_2: return "Conj_2";
        case ID_CONJ_3: return "Conj_3";
        case ID_PERIOD: return "$";
    }
    throw ERROR_LEXER_ID_NOT_FOUND;
    return "";
}
uint32_t name_to_id(std::string name)
{
    if(name == "int")    return ID_INT;
    if(name == "float")  return ID_FLOAT;
    if(name == "ident")  return ID_IDENT;
    if(name == "S'")     return ID_CS;
    if(name == "S")      return ID_S;
    if(name == "NP")     return ID_NP;
    if(name == "VP")     return ID_VP;
    if(name == "AP")     return ID_AP;
    if(name == "PP")     return ID_PP;
    if(name == "N")      return ID_N;
    if(name == "V")      return ID_V;
    if(name == "A'")     return ID_CA;
    if(name == "A")      return ID_A;
    if(name == "Noun")   return ID_NOUN;
    if(name == "Verb")   return ID_VERB;
    if(name == "Adj")    return ID_ADJ;
    if(name == "Adv")    return ID_ADV;
    if(name == "Modal")  return ID_MODAL;
    if(name == "Prep")   return ID_PREP;
    if(name == "Aux")    return ID_AUX;
    if(name == "Det")    return ID_DET;
    if(name == "Conj")   return ID_CONJ;
    if(name == "Conj_2") return ID_CONJ_2;
    if(name == "Conj_3") return ID_CONJ_3;
    if(name == "$")      return ID_PERIOD;
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

// lvalues for terminals that don't have rules
%token<ident_value> ID_N ID_V ID_NOUN ID_VERB
%token<ident_value> ID_ADJ ID_ADV ID_MODAL ID_PREP
%token<ident_value> ID_AUX ID_DET ID_CONJ ID_CONJ_2 ID_CONJ_3
%token<ident_value> ID_PERIOD

// lvalues for non-terminals that have rules
%type<symbol_value> CS S NP VP AP PP
%type<symbol_value> CA A

// lvalues for terminals that have rules
%type<symbol_value> N V Noun Verb
%type<symbol_value> Adj Adv Modal Prep
%type<symbol_value> Aux Det Conj Conj_2 Conj_3
%type<symbol_value> Period

// lexer IDs non-terminals
%nonassoc ID_CS ID_S ID_NP ID_VP ID_AP ID_PP
%nonassoc ID_CA ID_A

%%

root:
      CS    { pc->tree_context().root() = $1; YYACCEPT; }
    | error { yyclearin; /* yyerrok; YYABORT; */ }
    ;

CS:
      S            { $$ = MAKE_SYMBOL(ID_CS, @$, 1, $1); }
    | CS Conj_3 CS { $$ = MAKE_SYMBOL(ID_CS, @$, 3, $1, $2, $3); }
    ;

S:
      NP VP Period { $$ = MAKE_SYMBOL(ID_S, @$, 3, $1, $2, $3); }
    ;

NP:
      N          { $$ = MAKE_SYMBOL(ID_NP, @$, 1, $1); }
    | Det N      { $$ = MAKE_SYMBOL(ID_NP, @$, 2, $1, $2); }
    | NP Conj NP { $$ = MAKE_SYMBOL(ID_NP, @$, 3, $1, $2, $3); }
    ;

VP:
      V            { $$ = MAKE_SYMBOL(ID_VP, @$, 1, $1); }
    | V NP         { $$ = MAKE_SYMBOL(ID_VP, @$, 2, $1, $2); }
    | V NP PP      { $$ = MAKE_SYMBOL(ID_VP, @$, 3, $1, $2, $3); }
    | V AP         { $$ = MAKE_SYMBOL(ID_VP, @$, 2, $1, $2); }
    | VP Conj_2 VP { $$ = MAKE_SYMBOL(ID_VP, @$, 3, $1, $2, $3); }
    ;

AP:
      PP   { $$ = MAKE_SYMBOL(ID_AP, @$, 1, $1); }
    | A PP { $$ = MAKE_SYMBOL(ID_AP, @$, 2, $1, $2); }
    ;

PP:
      Prep NP { $$ = MAKE_SYMBOL(ID_PP, @$, 2, $1, $2); }
    | Prep PP { $$ = MAKE_SYMBOL(ID_PP, @$, 2, $1, $2); }
    ;

N:
      Noun    { $$ = MAKE_SYMBOL(ID_N, @$, 1, $1); }
    | CA Noun { $$ = MAKE_SYMBOL(ID_N, @$, 2, $1, $2); }
    ;

V:
      Verb    { $$ = MAKE_SYMBOL(ID_V, @$, 1, $1); }
    | Adv V   { $$ = MAKE_SYMBOL(ID_V, @$, 2, $1, $2); }
    | Modal V { $$ = MAKE_SYMBOL(ID_V, @$, 2, $1, $2); }
    ;

CA:
      A     { $$ = MAKE_SYMBOL(ID_CA, @$, 1, $1); }
    | CA CA { $$ = MAKE_SYMBOL(ID_CA, @$, 2, $1, $2); }
    ;

A:
      Adj     { $$ = MAKE_SYMBOL(ID_A, @$, 1, $1); }
    | Adv Adj { $$ = MAKE_SYMBOL(ID_A, @$, 2, $1, $2); }
    ;

Noun:
      ID_NOUN { $$ = MAKE_SYMBOL(ID_NOUN, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Verb:
      ID_VERB { $$ = MAKE_SYMBOL(ID_VERB, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Adj:
      ID_ADJ { $$ = MAKE_SYMBOL(ID_ADJ, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Adv:
      ID_ADV { $$ = MAKE_SYMBOL(ID_ADV, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Modal:
      ID_MODAL { $$ = MAKE_SYMBOL(ID_MODAL, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Prep:
      ID_PREP { $$ = MAKE_SYMBOL(ID_PREP, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Aux:
      ID_AUX { $$ = MAKE_SYMBOL(ID_AUX, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Det:
      ID_DET { $$ = MAKE_SYMBOL(ID_DET, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Conj:
      ID_CONJ { $$ = MAKE_SYMBOL(ID_CONJ, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Conj_2:
      ID_CONJ_2 { $$ = MAKE_SYMBOL(ID_CONJ_2, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Conj_3:
      ID_CONJ_3 { $$ = MAKE_SYMBOL(ID_CONJ_3, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

Period:
      ID_PERIOD { $$ = MAKE_SYMBOL(ID_PERIOD, @$, 1, MAKE_TERM(ID_IDENT, @$, $1)); }
    ;

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

    options_t()
        : mode(MODE_NONE), dump_memory(false)
    {}
};

bool extract_options_from_args(options_t* options, int argc, char** argv)
{
    if(!options)
        return false;
    int opt = 0;
    int longIndex = 0;
    static const char *optString = "i:e:lxgdmh?";
    static const struct option longOpts[] = {
                { "in-xml", required_argument, NULL, 'i' },
                { "expr",   required_argument, NULL, 'e' },
                { "lisp",   no_argument,       NULL, 'l' },
                { "xml",    no_argument,       NULL, 'x' },
                { "graph",  no_argument,       NULL, 'g' },
                { "dot",    no_argument,       NULL, 'd' },
                { "memory", no_argument,       NULL, 'm' },
                { "help",   no_argument,       NULL, 'h' },
                { NULL,     no_argument,       NULL, 0 }
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
            pos_value_path_ast_tuple->m_ast = _ast;
            return false;
        }
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
    switch(options.mode)
    {
        case options_t::MODE_LISP:  xl::mvc::MVCView::print_lisp(ast); break;
        case options_t::MODE_XML:   xl::mvc::MVCView::print_xml(ast); break;
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
    build_pos_value_paths_from_sentence(&pos_value_paths, options.expr);
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

int main(int argc, char** argv)
{
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