# jekyll-pub

A command-line tool that serves a local jekyll-based blog up via a rudimentary XML-RPC webserver, for use in blogging authoring tools like [MarsEdit](https://redsweater.com/marsedit/).

For more information, see [this blog post](https://davedelong.com/blog/2020/06/14/anything-worth-doing/).

## Usage

I use this with my personal blog, located at https://davedelong.com. In its git repository, I have this zsh script:

```zsh
#!/bin/zsh

if [ ! -d "_swift" ]; then
    mkdir _swift
fi
pushd _swift

if [ ! -d "jekyll-pub" ]; then
    echo "cloning..."
    git clone git@github.com:davedelong/jekyll-pub.git
else
    echo "pulling..."
    pushd jekyll-pub
    git reset --hard HEAD
    git pull
    popd
fi

popd
echo "running..."
open -a MarsEdit .
swift run --package-path _swift/jekyll-pub jekyll-pub .
```

Running this script (`./marsedit` in my case) automatically clones and updates this repository, opens MarsEdit, and starts the XML-RPC server.

MarsEdit itself is configured to use this via its preferences. I added a new blog with these connection settings:

```
System Name: WordPress
System API: WordPress API
API Endpoint URL: http://localhost:9080
Blog ID: 1
```
