%%
(ab|cd|ef|gh|ij|kl|mn|op|qr|st|uv|wx|yz)[0-9]{1,5} { printf("PAIR_DIGIT\n"); }
[abcde]+(123|456|789|000)*     { printf("GROUPED\n"); }
[a-z]{3,5}[0-9]{2,4}           { printf("ALPHANUM\n"); }
[^ \t\r\n]{10,}                { printf("LONG_TOKEN\n"); }
.                              { /* skip */ }
