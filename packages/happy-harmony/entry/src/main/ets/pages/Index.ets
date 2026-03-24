import { SodiumFFI } from 'common';
import { BufferUtils } from 'common';
import sodiumWrapper from 'libentry.so';

@Entry
@Component
struct Index {
  @State statusText: string = 'Initializing...';
  @State detailText: string = '';

  aboutToAppear(): void {
    SodiumFFI.setNativeModule(sodiumWrapper as ESObject);
    this.runCryptoTest();
  }

  runCryptoTest(): void {
    try {
      // Step 1: Initialize libsodium
      const initResult: number = SodiumFFI.sodiumInit();
      if (initResult !== 0) {
        this.statusText = 'FAIL: sodium_init returned ' + initResult;
        return;
      }
      this.statusText = 'sodium_init OK';

      // Step 2: Verify constants
      const boxNonceBytes: number = SodiumFFI.cryptoBoxNonceBytes;
      const boxPkBytes: number = SodiumFFI.cryptoBoxPublicKeyBytes;
      const boxSkBytes: number = SodiumFFI.cryptoBoxSecretKeyBytes;
      const signSeedBytes: number = SodiumFFI.cryptoSignSeedBytes;
      const sbKeyBytes: number = SodiumFFI.cryptoSecretboxKeyBytes;

      if (boxNonceBytes !== 24 || boxPkBytes !== 32 || boxSkBytes !== 32 ||
        signSeedBytes !== 32 || sbKeyBytes !== 32) {
        this.statusText = 'FAIL: constant mismatch';
        return;
      }

      // Step 3: Random bytes
      const random: Uint8Array = SodiumFFI.randomBytesBufNew(32);
      if (random.length !== 32) {
        this.statusText = 'FAIL: randomBytes length=' + random.length;
        return;
      }

      // Step 4: Ed25519 sign + verify
      const seed: Uint8Array = BufferUtils.fromUtf8String('test seed for harmony poc 1234');
      const testSeed: Uint8Array = new Uint8Array(32);
      for (let i: number = 0; i < 32 && i < seed.length; i++) {
        testSeed[i] = seed[i];
      }

      const keypair = SodiumFFI.cryptoSignSeedKeypair(testSeed);
      const testMessage: Uint8Array = BufferUtils.fromUtf8String('hello harmony');
      const signature: Uint8Array = SodiumFFI.cryptoSignDetached(testMessage, keypair.secretKey);
      if (signature.length !== 64) {
        this.statusText = 'FAIL: signature length=' + signature.length;
        return;
      }
      const verifyOk: boolean = SodiumFFI.cryptoSignVerifyDetached(signature, testMessage, keypair.publicKey);
      if (!verifyOk) {
        this.statusText = 'FAIL: Ed25519 verify failed';
        return;
      }

      // Step 5: SecretBox encrypt + decrypt
      const sbNonce: Uint8Array = SodiumFFI.randomBytesBufNew(24);
      const sbKey: Uint8Array = SodiumFFI.randomBytesBufNew(32);
      const sbPlain: Uint8Array = BufferUtils.fromUtf8String('secret message');
      const sbCipher: Uint8Array = SodiumFFI.cryptoSecretboxEasy(sbPlain, sbNonce, sbKey);
      const sbDecrypted: Uint8Array | null = SodiumFFI.cryptoSecretboxOpenEasy(sbCipher, sbNonce, sbKey);
      if (sbDecrypted === null) {
        this.statusText = 'FAIL: SecretBox decrypt failed';
        return;
      }
      const sbMatch: boolean = BufferUtils.equals(sbPlain, sbDecrypted);
      if (!sbMatch) {
        this.statusText = 'FAIL: SecretBox roundtrip mismatch';
        return;
      }

      // Step 6: Box encrypt + decrypt
      const aliceKp = SodiumFFI.cryptoBoxKeypair();
      const bobKp = SodiumFFI.cryptoBoxKeypair();
      const boxNonce: Uint8Array = SodiumFFI.randomBytesBufNew(24);
      const boxPlain: Uint8Array = BufferUtils.fromUtf8String('box hello');
      const boxCipher: Uint8Array =
        SodiumFFI.cryptoBoxEasy(boxPlain, boxNonce, bobKp.publicKey, aliceKp.secretKey);
      const boxDecrypted: Uint8Array | null =
        SodiumFFI.cryptoBoxOpenEasy(boxCipher, boxNonce, aliceKp.publicKey, bobKp.secretKey);
      if (boxDecrypted === null) {
        this.statusText = 'FAIL: Box decrypt failed';
        return;
      }
      const boxMatch: boolean = BufferUtils.equals(boxPlain, boxDecrypted);
      if (!boxMatch) {
        this.statusText = 'FAIL: Box roundtrip mismatch';
        return;
      }

      this.statusText = 'ALL TESTS PASSED';
      this.detailText = 'Ed25519 sign/verify OK | SecretBox OK | Box OK';
    } catch (e) {
      const errMsg: string = (e instanceof Error) ? (e as Error).message : String(e);
      this.statusText = 'ERROR: ' + errMsg;
    }
  }

  build() {
    Row() {
      Column() {
        Text(this.statusText)
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.statusText.startsWith('FAIL') || this.statusText.startsWith('ERROR')
            ? '#FF0000'
            : '#00AA00')
          .margin({ bottom: 16 })

        if (this.detailText !== '') {
          Text(this.detailText)
            .fontSize(16)
            .fontColor('#333333')
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
  }
}
