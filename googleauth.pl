#!/usr/bin/env perl
# https://developers.google.com/drive/v2/reference/files

use Mojolicious::Lite;
use Data::Dumper;

my $config = { client_id => "xxxxxxxxxx"
             , secret    => "xxxxxxxxxx"
             , scope     => 'https://www.googleapis.com/auth/drive.readonly'
             , oauth_url => 'https://accounts.google.com/o/oauth2'
             , cb        => 'http://localhost:3000/cb'
             };
# Home dir
get '/' => sub {
  my $c = shift;
  say "token '".$c->session->{access_token}."'" if $c->session->{access_token};
  # Reuse our token or ask for one
  #$c->session->{access_token} ? $c->flash(q => "'root' in parents")->redirect_to('/search') : $c->render('home')
  $c->render('home')
};

# Redirect to google's oauth
get '/auth' => sub {
  my $c = shift;
  $c->redirect_to( "$config->{oauth_url}/auth"
                 . "?client_id=$config->{client_id}"
                 . "&scope=$config->{scope}"
                 . '&redirect_uri='.$c->url_for('/cb')->to_abs
                 . '&response_type=code'
                 );
};

# OAuth callback
get '/cb' => sub {
  my $c = shift;
  my $res = $c->app->ua->post( "$config->{oauth_url}/token"
                             => { Accept => '*/*' }
                             => form => { code          => $c->param('code')
                                        , redirect_uri  => $c->url_for('/cb')->to_abs
                                        , client_id     => $config->{client_id}
                                        , client_secret => $config->{secret}
                                        , scope         => $config->{scope}
                                        , grant_type    => 'authorization_code'
                                        }
                             )->res;
  die "Error getting tokens" unless $res->code(200);

  # Save access token to session
  $c->session->{access_token} = $res->json->{access_token};
  $c->flash(q => "'root' in parents")->redirect_to('/search');
};

# Search files
get '/search' => sub {
  my $c = shift;

  # Read access token from session
  my $a_token = $c->session->{access_token} or die "No access token!";

  # Get the filelist
  my $c_res = $c->app->ua->get( "https://www.googleapis.com/drive/v2/files"
                                 => { Authorization => "Bearer $a_token" }
                                 => form => { maxResults => 1000
                                            , spaces     => 'drive'
                                            , orderBy    => 'folder,title'
                                            , q          => $c->session->{flash}->{q} || ''
                                            }
                                 )->res;
  $c->redirect_to('/') unless $c_res->code(200);
  $c->render( 'results', items => $c_res->json->{items} );
};

# List all children files for a given via search query. The id can be 'root' for the root folder.
get '/folder/#id' => { id => 'root' } => sub {
  my $c = shift;
  my $id = $c->param('id');
  $c->flash( q => "'$id' in parents" )->redirect_to('/search');
};

app->start;

  __DATA__
@@ home.html.ep
<a href='/auth'>Click here</a> to authenticate with Google OAuth.

@@ results.html.ep
<!DOCTYPE html>
<html>
  <head>
    <title>Upload</title>
    %= stylesheet 'https://cdnjs.cloudflare.com/ajax/libs/semantic-ui/2.2.4/semantic.min.css'
  </head>
  <body>
    <div class="ui main container">
      <div class="ui compact segment">
        <div class="ui right rail">
          <div class="sticky">
            <div class="ui compact segments">
              <div class="ui segment">
                <h3 class="ui header">Preview</h3>
              </div>
              <div class="ui segment">
                <img id="preview" class="ui bordered image" src="">
              </div>
              <div class="ui red segment">
                <p>Middle</p>
              </div>
              <div class="ui blue segment">
                <p>Middle</p>
              </div>
              <div class="ui green segment">
                <p>Middle</p>
              </div>
              <div class="ui yellow segment">
                <p>Bottom</p>
              </div>
            </div>
          </div>
        </div>
        <div class="ui mini divided animated selection list">
          <div class="item">
            <div class="content">
              <h3 class="ui header">Got <%= scalar @$items %> items.</h3>
            </div>
          </div>
          % foreach my $item (@$items) {
          <div id="object" class="item">
            <img class="ui image" src="<%= $item->{iconLink} %>">
            <div class="content">
            % if ($item->{mimeType} eq 'application/vnd.google-apps.folder') {
              <div class="ui sub header"><a href="<%= url_for('/folder/')."$item->{id}" %>" target="_blank"><%= $item->{title} %></a></div>
            % } else  {
              <div class="ui sub header" thumb="<%= $item->{thumbnailLink} %>"><a href="<%= $item->{alternateLink} %>" target="_blank"><%= $item->{title} %></a></div>
              <a href="<%= $item->{webContentLink} || $item->{exportLinks}->{'application/zip'}  %>">Download</a>
            % }
            </div>
          </div>
          % }
        </div>
      </div>
    </div>
    %= javascript 'https://ajax.googleapis.com/ajax/libs/jquery/1.12.4/jquery.min.js'
    %= javascript 'https://cdnjs.cloudflare.com/ajax/libs/semantic-ui/2.2.4/semantic.min.js'
    %= javascript begin
      $('#object.item').mouseover(function(){
         var thumb = $(this).find('div.ui.sub.header').attr('thumb');
         $('#preview').attr('src', thumb);
      });
      $(document).ready(function(){ $('.ui.sticky').sticky() })
    % end
  </body>
</html>
