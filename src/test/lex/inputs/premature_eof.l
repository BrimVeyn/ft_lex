/* multi line comment


				yolo
*/

KEYWORD     if|else|while|for|return
OP          \+|\-|\*|\/|==|!=|<=|>=|<|>|&&|\|\|

/*Single line comment		*/



STRUCTFIELD field[0-9]+

COMPLEX     {KEYWORD}|{ID}{SPACES}?{OP}?{NUM}?

%%

# Rules would start here

