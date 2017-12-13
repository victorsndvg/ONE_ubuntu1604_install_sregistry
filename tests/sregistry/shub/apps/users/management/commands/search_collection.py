'''

Copyright (c) 2017, Vanessa Sochat, All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

'''

from django.core.management.base import (
    BaseCommand,
    CommandError
)

#from shub.apps.main.query import collection_query
from shub.apps.main.models import Collection
from django.db.models import Q
from shub.logger import bot
import re

class Command(BaseCommand):
    '''add superuser will add admin and manager privs singularity 
    registry. The super user is an admin that can build, delete,
    and manage images
    '''
    def add_arguments(self, parser):
        # Positional arguments
        parser.add_argument('--collection', dest='collection', default=None, type=str)

    help = "Search for a collection."
    def handle(self,*args, **options):
        if options['collection'] is None:
            raise CommandError("Please provide a username with --collection")

        bot.debug("Collection: %s" %options['collection']) 

#        results = collection_query(options['collection'])
        results = Collection.objects.filter(Q(name__contains=options['collection']))
        for result in results:
            print(type(result))
            print("    uri: "+result.get_uri())
            print("    url: "+result.get_absolute_url())
            print("    private display:"+result.get_private_display())
#            print("    collection star:"+collection.has_collection_star())
#            print("    edit permission:"+collection.has_edit_permission())
#            print("    view permission:"+collection.has_view_permission())
#            print("    owner:"+collection.owner)
#            print("    owner id:"+collection.owner_id)
            print("    private:"+str(result.private))


