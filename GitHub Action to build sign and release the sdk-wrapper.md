# Fix neuron-sdk-wrapper copy/spawn to keep code signing

@viet.do.hoang to code sign the wrapper first

Thinking out loud. Is there a reason we are copying the SDK wrapper into the application and from it into the user directory? Is this actually what is happening? If so why doesn't the running .app just fetch the sdk-wrapper directly from GitHub?

I understand that bundling it into this download, into the .app download, we are feeling like we are signing everything. But actually we are signing only the outer shell.

The problem we're facing is that when copying that stuff from inside the package and into the user directory we are losing the code signing.

It is very likely why the firewall doesn't let it through.

So why don't we just sign the release of the sdk-wrapper in GitHub and this .app is just downloading the signed things on the fly.
