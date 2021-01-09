using UnityEditor;
using UnityEditor.Callbacks;
using UnityEditor.iOS.Xcode;
using System.IO;

namespace MusicPlayer
{
    public static class PostBuildProcess
    {

        [PostProcessBuild]
        public static void OnPostProcessBuild(BuildTarget buildTarget, string path)
        {
            if (buildTarget != BuildTarget.iOS)
            {
                return;
            }

            string plistPath = Path.Combine(path, "Info.plist");
            PlistDocument plist = new PlistDocument();
            plist.ReadFromFile(plistPath);
            PlistElementDict root = plist.root;

            if (root["NSAppleMusicUsageDescription"] != null)
            {
                return;
            }
            root.SetString("NSAppleMusicUsageDescription", "To play music");

            plist.WriteToFile(plistPath);
        }
    }
}