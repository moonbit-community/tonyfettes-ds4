const os = require('os');
const path = require('path');

const projectRoot = __dirname;
const platform = os.platform();
const pkg = 'tonyfettes/ds4';

let stubFlags = `-I${projectRoot}`;
let linkFlags;
let linkConfig = { package: pkg };
if (platform === 'darwin') {
  stubFlags += ' -ObjC -fobjc-arc';
  linkFlags = '-framework Foundation -framework Metal -pthread';
  linkConfig.link_flags = '-framework Foundation -framework Metal -pthread';
} else if (platform === 'linux') {
  stubFlags += ' -DDS4_NO_GPU';
  linkFlags = '-pthread';
  linkConfig.link_flags = '-pthread';
} else {
  throw new Error(`Unsupported platform for ds4 native binding: ${platform}`);
}

const output = {
  vars: {
    DS4_STUB_CC_FLAGS: stubFlags,
    DS4_CC_LINK_FLAGS: linkFlags,
  },
  link_configs: [linkConfig],
};

console.log(JSON.stringify(output));
