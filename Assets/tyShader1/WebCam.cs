using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class WebCam : MonoBehaviour {

    public WebCamTexture cameraTexture;
    private MeshRenderer renderer;

    // Use this for initialization
    void Start () {
        renderer = this.GetComponent<MeshRenderer>();

        StartCoroutine(Test1());
    }


    IEnumerator Test1()
    {
        yield return Application.RequestUserAuthorization(UserAuthorization.WebCam);

        bool isUser = Application.HasUserAuthorization(UserAuthorization.WebCam);
        isUser = false;

        if (!isUser)
        {
            WebCamDevice[] devices = WebCamTexture.devices;
            cameraTexture = new WebCamTexture(devices[0].name, 512, 384, 30);
            cameraTexture.Play();
            renderer.material.mainTexture = cameraTexture;
        }
    }
}
