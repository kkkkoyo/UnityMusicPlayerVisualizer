using UnityEngine;
using UnityEngine.UI;
using System;

namespace MusicPlayer
{
    public class Sample : MonoBehaviour
    {
        public Text infoLabel;
        public Text updateInfoLabel;
        public GameObject cube;
        private bool isQuitting = false;

        void OnEnable()
        {
            MusicPlayerPlugin.Instance.OnPlayingItemChanged += OnPlayingItemChanged;
            MusicPlayerPlugin.Instance.OnStateChanged += OnStateChanged;
            MusicPlayerPlugin.Instance.EndOfPlayback += EndOfPlayback;
            SetInfo();
        }


        void OnDisable()
        {
            if(isQuitting)
            {
                return;
            }
            MusicPlayerPlugin.Instance.OnPlayingItemChanged -= OnPlayingItemChanged;
            MusicPlayerPlugin.Instance.OnStateChanged -= OnStateChanged;
            MusicPlayerPlugin.Instance.EndOfPlayback -= EndOfPlayback;
        }

        void SetInfo()
        {
            var player = MusicPlayerPlugin.Instance.info;
            string title = player.title;
            string artist = player.artist;
            double duration = player.duration;

            var durationSpan = new TimeSpan(0, 0, (int) player.duration);
            string durationStr = durationSpan.ToString(@"mm\:ss").ToString();

            infoLabel.text = "state:" + MusicPlayerPlugin.Instance.State + "\ntitle:" + title + "\nartist:" + artist + "\nduration:" + durationStr;
        }

        void Update()
        {
            double currentTime = MusicPlayerPlugin.Instance.currentTime;
            float level = MusicPlayerPlugin.Instance.level;
            var currentTimeSpan = new TimeSpan(0, 0, (int) currentTime);
            string currentTimeStr = currentTimeSpan.ToString(@"mm\:ss").ToString();

            updateInfoLabel.text = "current time:" + currentTimeStr + "\nlevel:" + level;

            cube.transform.localScale = Vector3.one * level;
        }
        void EndOfPlayback()
        {
            Debug.Log("EndOfPlayback");
        }
        void OnPlayingItemChanged(MusicPlayer.Info info)
        {
            SetInfo();
        }

        void OnStateChanged(MusicPlayer.PlaybackState state)
        {
            SetInfo();
        }

        public void OnPlay()
        {
            Debug.Log("OnPlay");
            MusicPlayerPlugin.Instance.Play();
        }

        public void OnLoad()
        {
            Debug.Log("OnLoad");
            MusicPlayerPlugin.Instance.Load();
        }

        private void OnApplicationQuit () {
            isQuitting = true && Application.isEditor;
        }
    }
}