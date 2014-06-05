# debian e php5-fpm fastcgi

Se dopo l'upgrade odierno di debian php5-fpm i vostri siti web restituiscono erorre 500, sappiate che va dichiarato esplicitamente in _/etc/php5/fpm/pool.d/www.conf_:
 
    listen.owner = www-data
    listen.group = www-data

Poi un _service php5-fpm restart_ e tutto rifila liscio come l'olio :-)﻿