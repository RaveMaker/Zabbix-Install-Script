Zabbix-Install-Script
=====================

Zabbix installation on CentOS

Basically, the script tries to do a few things and assumes some things:
- Only run this for NEW installations, you will lose data if you run on an existing installation
- Run at your own risk
- Installs Zabbix 2.0.x on CentOS 6
- Do not corrupt an existing system
- Be able to run the script over and over in the event that it errors
- Be somewhat flexible
- The database server, web server, and zabbix server all run on one box

Version 0.7.0 (July 1, 2012) - Copyright (c) 2008-2012 [Brendon Baumgartner][Brendon Baumgartner]

Updated by [RaveMaker][RaveMaker].

[RaveMaker]: http://ravemaker.net
[Brendon Baumgartner]: http://blog.brendon.com
