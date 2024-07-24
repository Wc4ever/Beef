using Beefy.theme.dark;
using Beefy.gfx;
using System;
using Beefy.events;
using Beefy.widgets;
using System.Collections;
using System.Diagnostics;

namespace IDE.ui
{
	class AboutDialog : IDEDialog
	{
		static AboutDialog gAboutDialog;

		const int cWidth = 320;
		const int cHeight = 240;
		const int cRandSize = 3777;

		Font mBigFont ~ delete _;
		Font mMedFont ~ delete _;
		Font mSmFont ~ delete _;
		Image mImage ~ delete _;
		uint32[256] mPalette;
		uint8[cHeight][cWidth] mFire;
		uint8[cRandSize] mRand;
		int mRandIdx;

		Stopwatch mStopwatch = new .()..Start() ~ delete _;
		struct Entry
		{
			public double mUpdateCntF;
			public float mTimeMS;
		}
		List<Entry> mEntries = new .() ~ delete _;

		struct CColor
		{
			public uint8 r;
			public uint8 g;
			public uint8 b;
			public uint8 a;
		}

		public this()
		{
			Title = "About Beef IDE";

			mBigFont = new Font();
			mBigFont.Load("Segoe UI", GS!(80.0f));

			mMedFont = new Font();
			mMedFont.Load("Segoe UI", GS!(30.0f));

			mSmFont = new Font();
			mSmFont.Load("Segoe UI", GS!(20.0f));

			mImage = Image.CreateDynamic((.)cWidth, (.)cHeight);

			for (int x < cWidth)
			{
				mFire[cHeight-1][x] = 255;
			}

			Random rand = scope .(0xBEEF);
			for (int i < cRandSize)
				mRand[i] = (uint8)rand.NextI32();

			uint32[6] mainColors =
				.(
					0x00000000,
					0xFF000040,
					0xFFFF0000,
					0xFFFF8000,
					0xFFFFFF00,
					0xFFFFFFFF
				);

			for (int i < 256)
			{
				float colorPos = (i * 5 / 256.0f);

				Color colorOut = Color.ToNative(Color.Lerp(mainColors[(int)colorPos], mainColors[(int)colorPos + 1], colorPos - (int)colorPos));
				mPalette[i] = colorOut;
			}

			/*mWindowFlags |= .Resizable;
			mWindowFlags &= ~.Modal;*/

			gAboutDialog = this;
		}

		~this()
		{
			gAboutDialog = null;
		}

		public override void AddedToParent()
		{
			base.AddedToParent();
			mWidgetWindow.mWantsUpdateF = true;
		}

		public override void CalcSize()
		{
			mWidth = GS!(640);
			mHeight = GS!(480);
		}

		[Inline]
		public uint8 GetRand()
		{
			return mRand[(mRandIdx++) % cRandSize];
		}

		public void DoFire()
		{
			for (int y = 1; y < cHeight; y++)
			{
				for (int x < cWidth)
				{
					uint8* src = &mFire[y][x];
					uint8 pixel = *src;
					if (pixel <= 8)
					{
						src[-cWidth] = 0;
						continue;
					}

					uint8 randIdx = (uint8)GetRand();
					uint8* ptr = &src[-cWidth - (randIdx & 3) + 1];
					//uint8 randSub = (uint8)(randIdx & 7);
					uint8 randSub = (uint8)(randIdx % 7);
					*ptr = pixel - randSub;
				}
			}

			/*for (int i < 10000)
			{
				uint8* src = &mFire[0][0];

				int randOfs = (GetRand() * cWidth * (cHeight - 1)) / 256;
				src[randOfs] = (uint8)((int)(src[randOfs] * 2) / 2 / 1);
			}*/
		}

		public override void Draw(Graphics g)
		{
			using (g.PushColor(0xFF202020))
				g.FillRect(0, 0, mWidth, mHeight);

			if (mImage == null)
			{
				mImage = Image.CreateDynamic((.)mWidth, (.)mHeight);
			}

			uint32* newBits = new uint32[cWidth*cHeight]*;
			defer delete newBits;

			uint8* srcPtr = &mFire;
			uint32* destPtr = newBits;
			for (int y < cHeight)
			{
				for (int x < cWidth)
				{
					*(destPtr++) = mPalette[*(srcPtr++)];
				}
			}

			mImage.SetBits(0, 0, cWidth, cHeight, cWidth, newBits);

			float ang = Math.Min((float)(mUpdateCntF * 0.006f), Math.PI_f / 2);
			g.SetFont(mBigFont);
			g.DrawString("Beef IDE", 0, GS!(20) + (1.0f - Math.Sin(ang))*GS!(300), .Centered, mWidth);

			float angMed = Math.Min((float)(mUpdateCntF * 0.0055f), Math.PI_f / 2);
			float alpha = Math.Clamp((float)(mUpdateCntF * 0.007f) - 1.3f, 0, 1.0f);

			using (g.PushColor(Color.Get(alpha)))
			{
				using (g.PushTranslate(0, (1.0f - Math.Sin(angMed))*GS!(200)))
				{
					g.SetFont(mMedFont);
					g.DrawString("Copyright 2019 BeefyTech LLC", 0, GS!(120), .Centered, mWidth);
				}

				using (g.PushTranslate(0, (1.0f - Math.Sin(angMed))*GS!(300)))
				{
					g.SetFont(mSmFont);
					g.DrawString(scope String()..AppendF("Version {}", gApp.mVersionInfo.FileVersion), 0, GS!(170), .Centered, mWidth);
					g.DrawString(scope String()..AppendF("Build {}", gApp.mVersionInfo.ProductVersion), 0, GS!(200), .Centered, mWidth);
				}
			}

			g.DrawQuad(mImage, 0, 0, 0.0f, 0.0f, mWidth, mHeight, 1.0f, 1.0f);

			/*if (gAboutDialog == this)
			{
				/*Entry entry;
				entry.mTimeMS = mStopwatch.ElapsedMicroseconds / 1000.0f;
				entry.mUpdateCntF = mUpdateCntF;*/
				mEntries.Add(Entry() {mTimeMS = mStopwatch.ElapsedMicroseconds / 1000.0f, mUpdateCntF = mUpdateCntF});

				if (mEntries.Count == 100)
				{
					float prevTime = 0;

					for (var entry in mEntries)
					{
						Debug.WriteLine($"Entry Time:{entry.mTimeMS - prevTime:0.00} UpdateCntF:{entry.mUpdateCntF:0.00}");
						prevTime = entry.mTimeMS;

						if (@entry.Index == 20)
							break;
					}

					mEntries.Clear();
				}
			}

			using (g.PushColor(0xFFFFFFFF))
				g.FillRect(Math.Cos((float)(mUpdateCntF * 0.2f)) * 600 + mWidth / 2, 0, 8, mHeight);*/
		}

		public override void Update()
		{
			base.Update();
			MarkDirty();

			if (mRandIdx >= 0x4000'0000)
				mRandIdx = 0;

			DoFire();
		}

		public override void UpdateF(float updatePct)
		{
			base.UpdateF(updatePct);
			MarkDirty();
		}

		public override void KeyDown(KeyCode keyCode, bool isRepeat)
		{
			base.KeyDown(keyCode, isRepeat);

			if ((keyCode == (.)'C') && (mWidgetWindow.GetKeyFlags(true) == .Ctrl))
			{
				String versionInfo = scope String();
				versionInfo.AppendF("Beef IDE Version {}", gApp.mVersionInfo.FileVersion);
				versionInfo.AppendF(" Build {}", gApp.mVersionInfo.ProductVersion);
				gApp.SetClipboardText(versionInfo);
			}
		}
	}
}
